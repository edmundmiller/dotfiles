#!/usr/bin/env python3
"""Finite host coordinator and fixed SELFTEST actor in the existing serial orb."""

import contextlib
import binascii
import fcntl
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import select
import socket
import struct
import subprocess
import sys
import tempfile
import time


SOCKET = "/run/note4c-headset/control.sock"
OWNER = "amp-01a1f05a-2cb2-73dc-ab1d-7f51b1b4f508"
PYTHON = "/home/user/.cache/uv/archive-v0/S1184gpX2erfcGlI3QYeM/bin/python"
PRIVATE = Path("/home/user/workspace/repo/.amp/in/private-note4c-acceptance")
APP = "c8cdb8c66e01f74a5af31a215ff34e24bbdfa043b6d0b5abf5e5b9d5f086429f"
SOURCE = "eb9beeb9ac49c74f8800bfb608200b940e6cb4d29bf1f526fe19feb8f6b5b3be"
GUARD = "106dc89878fd4cfd56f4ebc3f9bbdff8de1a899ec705cb1ab33465a04bf35e8f"


def emit(data):
    print(json.dumps(data, allow_nan=False), flush=True)


def message(stream, event, timeout):
    if not select.select([stream], [], [], timeout)[0]:
        raise ValueError("Controller event timed out: " + event)
    raw = stream.readline(32769)
    if len(raw) > 32768 or not raw.endswith(b"\n"):
        raise ValueError("Controller disconnected or exceeded message limit")
    item = json.loads(raw)
    if item.get("event") == "owner_error":
        raise ValueError("Device-owner execution failed: " + item["detail"])
    if item.get("event") != event:
        raise ValueError("Unexpected controller event")
    return item


def send(stream, data):
    stream.write(json.dumps(data, allow_nan=False).encode() + b"\n")
    stream.flush()


def clean_line(raw):
    text = re.sub(r"\x1b\[[0-9;]*m", "", raw.decode(errors="replace")).strip()
    return "" if any(char in text for char in ('{', '}', '"')) else text


def board_lines(port, deadline):
    pending = bytearray()
    while time.monotonic() < deadline:
        pending.extend(port.read(4096))
        if len(pending) > 65536:
            raise ValueError("Serial line limit exceeded")
        while b"\n" in pending:
            raw, _, pending = pending.partition(b"\n")
            text = clean_line(raw)
            if any(needle in text for needle in ("Guru Meditation", "panic'ed", "assert failed",
                    "CORRUPTED", "Failed to mount filesystem", "NOTE4C audio failed:",
                    "NOTE4C audio armed:", "NOTE4C audio capturing:")):
                raise ValueError("Unexpected runtime/audio state")
            yield text
    raise ValueError("Board response deadline; outcome unknown, no retry")


def selftest(port, trial_id, deadline, marker):
    if time.monotonic() >= deadline:
        raise ValueError("Expired stimulus admission; no command sent")
    # Durable before transmission, including partial writes and lost replies.
    with marker.open("x") as output:
        output.write(trial_id)
        output.flush()
        os.fsync(output.fileno())
    directory = os.open(marker.parent, os.O_DIRECTORY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)
    if time.monotonic() >= deadline:
        raise ValueError("Admission expired during durable reservation")
    sent = time.monotonic()
    command = b"NOTE4C_AUDIO_SELFTEST\n"
    if port.write(command) != len(command):
        raise ValueError("Partial serial write; outcome unknown")
    port.flush()
    started, speaker, codec_at, stages = False, False, None, []
    for text in board_lines(port, sent + 8):
        if "ESP-ROM:esp32s3" in text or "BL init success" in text:
            raise ValueError("Reboot after command; outcome unknown")
        if text == "NOTE4C selftest: local microphone plus two capped tones; maximum 5s; no saved audio":
            if started:
                raise ValueError("Duplicate SELFTEST start")
            started = True
        if not started:
            if text.startswith("NOTE4C selftest"):
                raise ValueError("Completion without fresh start")
            continue
        if re.fullmatch(r"NOTE4C speaker volume=70 before_dac=0x[0-9a-f]+ before_mute=0x[0-9a-f]+ dac=0x[0-9a-f]+ muted=0", text):
            speaker = True
        if re.fullmatch(r"NOTE4C codec reg=0x44 value=0x[0-9a-f]+", text):
            codec_at = time.monotonic()
        match = re.fullmatch(r"NOTE4C selftest stage=(\d+) pa=(\d+) samples=(\d+) rms=([\d.]+) hz1000=([\d.]+) hz2000=([\d.]+) clipped=(\d+)", text)
        if match:
            stages.append(dict(zip(("stage", "pa", "samples", "rms", "hz1000", "hz2000", "clipped"),
                [int(match[1]), int(match[2]), int(match[3]), float(match[4]),
                    float(match[5]), float(match[6]), int(match[7])])))
        terminal = re.fullmatch(r"NOTE4C selftest result=(PASS|FAIL); muted; no recording retained", text)
        if terminal:
            if not speaker or codec_at is None or len(stages) != 5:
                raise ValueError(f"Incomplete matched SELFTEST evidence: speaker={speaker}, codec={codec_at is not None}, stages={len(stages)}")
            return {"event": "board_result", "result": {"trial_id": trial_id,
                "verdict": terminal[1], "muted": True, "stages": stages,
                "command_monotonic": sent, "codec_ready_monotonic": codec_at,
                "complete_monotonic": time.monotonic()}}


def load_guard():
    source = (PRIVATE / "device_gate.py").read_text()
    if hashlib.sha256(source.encode()).hexdigest() != GUARD:
        raise ValueError("Accepted private identity guard changed")
    # Keep the accepted identity/exclusion/mount/fd checks, but read a serial
    # attribute only for the approved vendor/product, never unrelated devices.
    old = "identity = tuple((entry / key).read_text().strip() for key in ('idVendor', 'idProduct', 'serial'))"
    new = "ids = tuple((entry / key).read_text().strip() for key in ('idVendor', 'idProduct'))\n            identity = (*ids, (entry / 'serial').read_text().strip() if ids == ('303a', '1001') else '')"
    if source.count(old) != 1:
        raise ValueError("Private identity guard no longer matches reviewed source")
    scope = {"__name__": "shared_device_gate", "__file__": str(PRIVATE / "device_gate.py")}
    exec(compile(source.replace(old, new), scope["__file__"], "exec"), scope)
    return scope


def active_application(metadata):
    # The same ESP-IDF parser and CRC-valid OTA selection as the accepted
    # private readback procedure. No bootloader, partition or OTA writes.
    parser = Path.home() / ".platformio/packages/framework-espidf/components/partition_table/gen_esp32part.py"
    spec = importlib.util.spec_from_file_location("esp_partitions", parser)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    table = module.PartitionTable.from_binary(metadata[:0xc00])
    table.verify()
    ota = next(part for part in table if part.type == 1 and part.subtype == 0)
    sequences = []
    for index in range(2):
        sequence, _, state, crc = struct.unpack_from("<I20sII", metadata, ota.offset - 0x8000 + index * 4096)
        if sequence != 0xffffffff and state not in (3, 4) and crc == binascii.crc32(struct.pack("<I", sequence), 0xffffffff):
            sequences.append(sequence)
    apps = sorted((part for part in table if part.type == 0 and 0x10 <= part.subtype < 0x20), key=lambda part: part.subtype)
    if not sequences or not apps:
        raise ValueError("No CRC-valid OTA application selection")
    active = apps[(max(sequences) - 1) % len(apps)]
    if active.subtype != 0x10 or active.offset != 0x20000 or active.size < 0x186f70:
        raise ValueError("Unexpected active application slot")


def actor():
    import serial
    from esptool.reset import HardReset

    os.umask(0o077)
    session = message(sys.stdin.buffer, "reservation", 10)
    trials = session["trial_ids"]
    expires = session["expires"]
    if not time.monotonic() < expires <= time.monotonic() + 240:
        raise ValueError("Invalid or expired shared reservation")
    if len(trials) != 2 or len(set(trials)) != 2 or any(not re.fullmatch("[0-9a-f]{32}", trial) for trial in trials):
        raise ValueError("Expected two distinct shared reservations")
    gate = load_guard()
    with (PRIVATE / "shared-controller.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        session_dir = PRIVATE / ("shared-" + trials[0])
        session_dir.mkdir(mode=0o700)  # Existing directory forbids a replay/reset.
        with contextlib.redirect_stdout(io.StringIO()):
            expected = gate["preflight"]()
        # Read-only application verification in ROM, through the same custody
        # and lock. Never invoke the historical operator's write entry point.
        with tempfile.TemporaryDirectory(prefix="note4c-provenance-", dir="/dev/shm") as directory:
            for name, before, offset, length in (("metadata", "usb-reset", "0x8000", "0x18000"),
                    ("application", "no-reset", "0x20000", "0x186f70")):
                target = Path(directory) / name
                with contextlib.redirect_stdout(io.StringIO()):
                    gate["preflight"]()
                subprocess.run([sys.executable, "-m", "esptool", "--chip", "esp32s3",
                    "--port", str(gate["PORT"]), "--baud", "460800", "--before", before,
                    "--after", "no-reset", "read-flash", offset, length, str(target)],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True,
                    timeout=min(60, max(1, expires - time.monotonic())))
                if name == "metadata":
                    active_application(target.read_bytes())
                elif hashlib.sha256(target.read_bytes()).hexdigest() != APP:
                    raise ValueError("Fresh application readback mismatch; no audio command")
        with contextlib.redirect_stdout(io.StringIO()):
            expected = gate["preflight"]()
        port = serial.Serial(port=None, baudrate=115200, timeout=0.05, write_timeout=1, exclusive=True)
        port.dtr, port.rts, port.port = False, False, str(gate["PORT"])
        port.open()
        try:
            if os.fstat(port.fileno()).st_rdev != expected:
                raise ValueError("Opened serial identity changed")
            with contextlib.redirect_stdout(io.StringIO()):
                HardReset(port, uses_usb=True)()
            healthy = set()
            for text in board_lines(port, min(time.monotonic() + 180, expires - 10)):
                for needle, flag in (("ESP-ROM:esp32s3", "boot"), ("BL init success", "boot"),
                        ("Filesystem mounted", "filesystem"),
                        ("Zectrix Note4C native EPD update end: ok=1", "panel"),
                        ("NOTE4C USB maintenance: external power detected; deferring sleep", "maintenance"),
                        ("NOTE4C audio startup holds", "muted_start")):
                    if needle in text:
                        healthy.add(flag)
                if len(healthy) == 5:
                    break
            emit({"event": "board_ready", "provenance": {"application_sha256": APP,
                "source_sha256": SOURCE, "fresh_application_readback": True,
                "fresh_boot_panel_maintenance": True, "active_ota_verified": True, "session_id": trials[0],
                "monotonic": time.monotonic(), "actor_sha256": session["actor_sha256"]}})
            for index, trial in enumerate(trials):
                request = message(sys.stdin.buffer, "selftest", 20)
                if (request["trial_id"] != trial or request["deadline"] > expires
                        or os.fstat(port.fileno()).st_rdev != expected):
                    raise ValueError("Reservation or serial identity changed")
                with contextlib.redirect_stdout(io.StringIO()):
                    if gate["preflight"]() != expected:
                        raise ValueError("Serial identity changed before command")
                # Drain and reject stale/reboot/error evidence before admission.
                while port.in_waiting:
                    for text in port.read(port.in_waiting).splitlines():
                        line = clean_line(text)
                        if any(word in line for word in ("ESP-ROM:", "BL init success", "NOTE4C audio", "NOTE4C selftest", "panic", "Guru Meditation")):
                            raise ValueError("Unexpected state before admission")
                emit(selftest(port, trial, request["deadline"], session_dir / f"command-{index}"))
        finally:
            port.close()


def coordinate():
    if os.geteuid() != 0 or socket.gethostname() != "nuc":
        raise ValueError("Coordinator requires root on the NUC")
    if Path("/etc/amp-orbs/note4c-orb").read_text().strip() != OWNER:
        raise ValueError("Serial custody pin changed")
    import pwd
    account = pwd.getpwnam("amp-orbs")
    uid, home = account.pw_uid, account.pw_dir
    podman = ["sudo", "-n", "-u", "amp-orbs", "env", f"HOME={home}",
        f"XDG_RUNTIME_DIR=/run/user/{uid}", f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{uid}/bus",
        "CONTAINERS_STORAGE_CONF=/etc/amp-orbs/storage.conf", "podman"]
    # Match the host dispatcher: rootless Podman must not inherit the SSH
    # caller's working directory, which this dedicated account cannot traverse.
    running = subprocess.run([*podman, "inspect", "--format", '{{.State.Running}} {{index .Config.Labels "io.dotfiles.amp-orb"}}', OWNER],
        stdin=subprocess.DEVNULL, capture_output=True, cwd=home, timeout=10, text=True)
    if running.returncode:
        raise ValueError(f"Owner container inspection failed (exit {running.returncode}); no reservation or device open")
    if running.stdout.strip() != "true true":
        raise ValueError("Existing device-owning orb is not running; do not wake or migrate it")
    source = Path(__file__).read_text()
    digest = hashlib.sha256(source.encode()).hexdigest()
    probe = subprocess.run([*podman, "exec", "--user", "1000:1000", "-i", OWNER,
        PYTHON, "-u", "-c", source, "--probe"], stdin=subprocess.DEVNULL,
        capture_output=True, cwd=home, timeout=10)
    if probe.returncode or json.loads(probe.stdout) != {"event": "owner_probe", "ready": True}:
        raise ValueError("Device-owner environment probe failed; no reservation or device open")
    process = None
    with socket.socket(socket.AF_UNIX) as connection:
        ready_by = time.monotonic() + 15
        while True:
            try:
                connection.connect(SOCKET)
                break
            except FileNotFoundError:
                if time.monotonic() >= ready_by:
                    raise ValueError("Shared bench socket unavailable")
                time.sleep(0.1)
        connection.settimeout(260)
        with connection.makefile("rwb", buffering=0) as bench:
            reservation = message(bench, "reserved", 90)
            try:
                # Execute only this exact published source as the existing orb's
                # ordinary UID. No TTY, listener, new grant or persisted actor.
                process = subprocess.Popen([*podman, "exec", "--user", "1000:1000", "-i", OWNER,
                    PYTHON, "-u", "-c", source, "--actor"], stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0, cwd=home)
                send(process.stdin, {"event": "reservation", "actor_sha256": digest,
                    "trial_ids": [trial["trial_id"] for trial in reservation["trials"]],
                    "expires": reservation["expires"]})
                ready = message(process.stdout, "board_ready", 250)
                provenance = ready["provenance"]
                if (provenance["application_sha256"] != APP or provenance["actor_sha256"] != digest
                        or not provenance["active_ota_verified"] or not provenance["fresh_application_readback"]
                        or not provenance["fresh_boot_panel_maintenance"]
                        or abs(provenance["monotonic"] - time.monotonic()) > 0.25):
                    raise ValueError("Actor clock/transport mismatch")
                send(bench, ready)
                for index, event in enumerate(("capture_ready", "reference_ready")):
                    if index:
                        message(bench, "output_measured", 15)
                        send(bench, {"event": "run_input"})
                    admission = message(bench, event, 15)
                    send(process.stdin, {**admission, "event": "selftest"})
                    send(bench, message(process.stdout, "board_result", 10))
                complete = message(bench, "complete", 120)
                if process.wait(timeout=3) != 0:
                    raise ValueError("Actor did not close cleanly")
                emit(complete)
            finally:
                if process is not None:
                    process.stdin.close()
                    # Do not kill a serial actor with an uncertain in-flight
                    # command. Its bounded local observer closes after 8s.
                    process.wait(timeout=12)


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--actor"]:
            actor()
        elif sys.argv[1:] == ["--probe"]:
            import serial
            import esptool
            with contextlib.redirect_stdout(io.StringIO()):
                load_guard()["preflight"]()
            if not (Path.home() / ".platformio/packages/framework-espidf/components/partition_table/gen_esp32part.py").is_file():
                raise ValueError("Accepted partition parser is unavailable")
            emit({"event": "owner_probe", "ready": True})
        elif sys.argv[1:] == ["--coordinate"]:
            coordinate()
        else:
            raise ValueError("Expected --actor, --probe or --coordinate")
    except Exception as error:
        detail = str(error) if isinstance(error, (ValueError, AssertionError)) else type(error).__name__
        if sys.argv[1:] in (["--actor"], ["--probe"]):
            emit({"event": "owner_error", "detail": detail})
        print("Shared controller failed: " + detail, file=sys.stderr)
        sys.exit(1)
