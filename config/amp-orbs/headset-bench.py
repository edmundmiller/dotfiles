#!/usr/bin/env python3
"""Inspect the NUC headset, or run its explicitly started, bounded calibration."""

from array import array
from concurrent.futures import ThreadPoolExecutor
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import select
import socket
import subprocess
import sys
import threading
import time
import uuid


def inspect_headset(root=Path("/"), amixer="amixer"):
    pci = root / "sys/devices/pci0000:00/0000:00:1f.3"
    if ((pci / "vendor").read_text().strip() != "0x8086"
            or (pci / "device").read_text().strip() != "0x02c8"
            or (pci / "driver").resolve(strict=True).name != "snd_hda_intel"):
        raise ValueError("Unexpected analog audio controller")
    cards = [card for card in (root / "sys/class/sound").glob("card[0-9]*")
        if card.resolve(strict=True).parent == pci / "sound"]
    if len(cards) != 1:
        raise ValueError("Expected exactly one card on the approved controller")
    card = cards[0].name.removeprefix("card")
    proc = root / f"proc/asound/card{card}"
    if (proc / "codec#0").read_text().splitlines()[0] != "Codec: Realtek ALC256":
        raise ValueError("Unexpected analog codec")
    endpoints = {}
    for direction in ("c", "p"):
        pcm = root / f"sys/class/sound/pcmC{card}D0{direction}"
        if pcm.resolve(strict=True).parent != pci / "sound" / f"card{card}":
            raise ValueError("Analog endpoint is outside the approved controller")
        endpoints[direction] = {"name": pcm.name, "dev": (pcm / "dev").read_text().strip(),
            "status": (proc / f"pcm0{direction}/sub0/status").read_text().strip()}

    def read_controls(*arguments):
        return subprocess.run([amixer, "--card", card, *arguments],
            capture_output=True, text=True, check=True, timeout=5).stdout.strip()

    controls = {}
    for line in read_controls("controls").splitlines():
        match = re.fullmatch(
            r"numid=(\d+),iface=(?:MIXER|CARD),name='([^']+)'(?:,index=(\d+))?", line)
        if match and re.match(
                r"^(?:Master|PCM|Headphone|Headset Mic|Internal Mic|Capture|Input Source|Auto-Mute Mode)(?: |$)",
                match[2]):
            controls[match[1]] = {"name": match[2], "index": int(match[3] or 0),
                "readback": read_controls("cget", f"numid={match[1]}")}
    return {"controller": "0000:00:1f.3", "codec": "Realtek ALC256",
        "card_index": int(card), "endpoints": endpoints, "controls": controls,
        "control_reads_only": True, "pcm_opened": False, "settings_changed": False,
        "acoustic_signal_verified": False}


STATE = Path("/var/lib/note4c-headset")
RATE = 48000
SECONDS = 6
# Explicit controls from the inspected ALC256. Never touch internal mic boosts,
# defaults, HDMI, Bluetooth, or a caller-selected control/path/level.
ROUTE = {
    "Capture Switch": "off,off",
    "Capture Source": "2",
    "Capture Volume": "23,23",
    "Headset Mic Boost Volume": "0,0",
    "Master Playback Volume": "60,60",
    "Master Playback Switch": "on,on",
}


def values(control):
    match = re.search(r"^\s*: values=([^\n]+)$", control["readback"], re.MULTILINE)
    if not match:
        raise ValueError("Missing control value")
    return match[1]


def selected_controls(status):
    controls = {}
    for number, control in status["controls"].items():
        if control["name"] in ROUTE and control["index"] == 0:
            if control["name"] in controls:
                raise ValueError("Ambiguous control")
            controls[control["name"]] = {**control, "numid": number}
    if controls.keys() != ROUTE.keys():
        raise ValueError("Required headset controls missing")
    source = controls["Capture Source"]["readback"]
    if re.findall(r"Item #(\d+) 'Headset Mic'", source) != ["2"]:
        raise ValueError("Headset source contract changed")
    for name, maximum, scale in (
            ("Master Playback Volume", 87, "-65.25dB,step=0.75dB"),
            ("Capture Volume", 63, "-17.25dB,step=0.75dB"),
            ("Headset Mic Boost Volume", 3, "0.00dB,step=10.00dB")):
        text = controls[name]["readback"]
        if f"values=2,min=0,max={maximum}," not in text or scale not in text:
            raise ValueError("Headset gain contract changed")
    return controls


def save_json(path, data):
    temporary = path.with_suffix(".tmp")
    with temporary.open("w") as output:
        json.dump(data, output, sort_keys=True)
        output.flush()
        os.fsync(output.fileno())
    temporary.replace(path)
    descriptor = os.open(path.parent, os.O_DIRECTORY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def claim_trial(state, now):
    path = state / "ledger.json"
    ledger = json.loads(path.read_text()) if path.exists() else []
    if any(entry["started"] > now for entry in ledger):
        raise ValueError("Trial clock moved backwards")
    ledger = [entry for entry in ledger if now - entry["started"] < 1800]
    if len(ledger) >= 10:
        raise ValueError("Ten-trial rolling 30-minute budget exhausted")
    trial = {"trial_id": uuid.uuid4().hex, "started": now, "result": "reserved"}
    ledger.append(trial)
    save_json(path, ledger)
    return ledger, trial


def mixer(card, control, new_value=None):
    command = ["amixer", "--card", str(card),
        "cget" if new_value is None else "cset", f"numid={control['numid']}"]
    if new_value is not None:
        command.append(new_value)
    text = subprocess.run(command, capture_output=True, text=True, check=True,
        timeout=3).stdout
    # Revalidate the numid's name/index instead of trusting enumeration numbers.
    header = text.splitlines()[0]
    expected_index = f",index={control['index']}" if control["index"] else ""
    if not header.endswith(f",name='{control['name']}'{expected_index}"):
        raise ValueError("Control identity changed")
    return values({"readback": text})


def restore(state):
    path = state / "restore.json"
    if not path.exists():
        return
    snapshot = json.loads(path.read_text())
    status = inspect_headset()
    controls = selected_controls(status)
    if any(endpoint["status"] != "closed" for endpoint in status["endpoints"].values()):
        raise ValueError("Cannot restore while an analog stream is open")
    errors = []
    # Restore capture enable last, after source and gains, with no PCM open.
    names = [name for name in reversed(ROUTE) if name != "Capture Switch"]
    for name in [*names, "Capture Switch"]:
        control = controls[name]
        baseline = snapshot[name]
        planned = "on,on" if name == "Capture Switch" else ROUTE[name]
        try:
            current = mixer(status["card_index"], control)
            if current not in (baseline, planned, "off,off" if name == "Capture Switch" else baseline):
                errors.append(name)
                continue  # Do not overwrite another actor's different setting.
            if current != baseline:
                if mixer(status["card_index"], control, baseline) != baseline:
                    errors.append(name)
        except (OSError, ValueError, subprocess.SubprocessError):
            errors.append(name)
    if errors:
        raise ValueError("Restoration conflict/failure: " + ", ".join(errors))
    path.unlink()
    # Ensure an interrupted unlink cannot resurrect an old recovery snapshot.
    descriptor = os.open(state, os.O_DIRECTORY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def tone():
    samples = array("h")
    for frequency in (1000, 2000):
        for index in range(RATE):
            # Fixed peak -18 dBFS; master raw 60 is -20.25 dB, below 70%.
            amplitude = round(4096 * math.sin(2 * math.pi * frequency * index / RATE))
            samples.extend((amplitude, amplitude))
    if sys.byteorder != "little":
        samples.byteswap()
    return samples.tobytes()


def score(raw):
    if len(raw) != RATE * SECONDS * 4:
        raise ValueError("Incomplete six-second stereo capture")
    samples = array("h", raw)
    if sys.byteorder != "little":
        samples.byteswap()
    channels = []
    for channel in (samples[::2], samples[1::2]):
        blocks = [channel[start:start + RATE // 4]
            for start in range(0, len(channel), RATE // 4)]
        measurements = {}
        for frequency in (1000, 2000):
            coefficient = 2 * math.cos(2 * math.pi * frequency / RATE)
            powers = []
            for block in blocks:
                previous = older = 0.0
                for sample in block:
                    current = sample + coefficient * previous - older
                    older, previous = previous, current
                powers.append(max(0, previous ** 2 + older ** 2
                    - coefficient * previous * older) * 2 / len(block) ** 2)
            background = max([*powers[:3], *powers[-4:]], default=0)
            signal = max(powers[4:16])
            measurements[str(frequency)] = {
                "signal_dbfs": round(10 * math.log10(max(signal, 1e-20) / 32768 ** 2), 2),
                "rise_db": round(10 * math.log10(max(signal, 1e-20)
                    / max(background, 1e-20)), 2),
                "detected": signal > 4 * max(background, 1.0),
            }
        clipped = sum(abs(sample) >= 32760 for sample in channel)
        channels.append({"peak": max(map(abs, channel)), "clipped_samples": clipped,
            "tones": measurements,
            "detected": not clipped and all(item["detected"] for item in measurements.values())})
    return {"channels": channels, "signal_detected": any(item["detected"] for item in channels),
        "sample_rate": RATE, "capture_seconds": SECONDS,
        "raw_audio_retained": False, "intelligibility_verified": False,
        "note4c_path_verified": False}


def record_tones(card, controls, reference):
    processes = []
    deadline = None
    executor = ThreadPoolExecutor(max_workers=2)
    try:
        capture = subprocess.Popen(["arecord", "--device", f"hw:{card},0", "--quiet",
            "--file-type", "raw", "--format", "S16_LE", "--rate", str(RATE),
            "--channels", "2", "--duration", str(SECONDS)],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
        processes.append(capture)
        # Independent of mixer reads or a blocked collector. The service also
        # kills its entire cgroup on timeout. Neither is a hard-real-time claim.
        deadline = threading.Timer(8, capture.kill)
        deadline.start()
        # Wait for one second of real samples, not a guessed playback delay.
        prefix = bytearray()
        ready_by = time.monotonic() + 3
        while len(prefix) < RATE * 4:
            remaining = ready_by - time.monotonic()
            if remaining <= 0 or not select.select([capture.stdout], [], [], remaining)[0]:
                raise ValueError("Capture readiness timed out")
            part = capture.stdout.read(RATE * 4 - len(prefix))
            if not part:
                raise ValueError("Capture did not start")
            prefix.extend(part)
        reading = executor.submit(capture.communicate, timeout=8)
        playback = subprocess.Popen(["aplay", "--device", f"hw:{card},0", "--quiet",
            "--file-type", "raw", "--format", "S16_LE", "--rate", str(RATE),
            "--channels", "2"], stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        processes.append(playback)
        playing = executor.submit(playback.communicate, reference, timeout=4)
        while not reading.done():
            # Route drift invalidates this trial. No internal-mic fallback.
            for name, planned in ROUTE.items():
                expected = "on,on" if name == "Capture Switch" else planned
                if mixer(card, controls[name]) != expected:
                    raise ValueError("Headset routing changed during capture")
            time.sleep(0.2)
        raw, _ = reading.result()
        playing.result()
        if capture.returncode or playback.returncode:
            raise ValueError("Analog recording/playback failed")
        return score(prefix + raw)
    finally:
        # Kill before joining collector threads, including on routing drift.
        for process in reversed(processes):
            if process.poll() is None:
                process.kill()
            process.wait(timeout=2)
        if deadline is not None:
            deadline.cancel()
            deadline.join()
        executor.shutdown(wait=True)


def calibrate(state):
    if (state / "restore.json").exists():
        raise ValueError("Previous routing restoration unresolved; no new trial")
    status = inspect_headset()
    controls = selected_controls(status)
    if any(endpoint["status"] != "closed" for endpoint in status["endpoints"].values()):
        raise ValueError("An analog stream is already open")
    jacks = [control for control in status["controls"].values()
        if control["name"] == "Headphone Jack" and control["index"] == 0]
    if len(jacks) != 1 or values(jacks[0]) != "on":
        raise ValueError("Headphone jack is not connected")
    reference = tone()
    ledger, trial = claim_trial(state, time.time())
    trial.update({"kind": "headset_calibration", "card_index": status["card_index"],
        "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "fixture_sha256": hashlib.sha256(reference).hexdigest(),
        "route": {**ROUTE, "Capture Switch": "on,on"},
        "raw_audio_retained": False, "controls_restored": False,
        "physical_setup_verified": False})
    save_json(state / "ledger.json", ledger)
    save_json(state / "restore.json", {name: values(control) for name, control in controls.items()})
    try:
        for name, planned in ROUTE.items():
            if mixer(status["card_index"], controls[name]) != values(controls[name]):
                raise ValueError("Headset controls changed before setup")
            if mixer(status["card_index"], controls[name], planned) != planned:
                raise ValueError("Headset setup readback failed")
        if mixer(status["card_index"], controls["Capture Switch"], "on,on") != "on,on":
            raise ValueError("Headset capture enable failed")
        trial.update(record_tones(status["card_index"], controls, reference))
        trial["result"] = "measured"
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        trial["result"] = "failed"
        trial["error"] = str(error)
        raise
    finally:
        try:
            restore(state)
            trial["controls_restored"] = True
        finally:
            save_json(state / "ledger.json", ledger)
            print(json.dumps(trial, sort_keys=True), flush=True)


if __name__ == "__main__":
    try:
        if socket.gethostname() != "nuc":
            raise ValueError("Run only on the NUC host")
        if sys.argv[1:] in (["--calibrate"], ["--restore"]):
            with (STATE / "bench.lock").open("a") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                (calibrate if sys.argv[1] == "--calibrate" else restore)(STATE)
        elif not sys.argv[1:]:
            print(json.dumps(inspect_headset(), sort_keys=True))
        else:
            raise ValueError("Expected no arguments, --calibrate, or --restore")
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Headset bench failed: {error}", file=sys.stderr)
        sys.exit(1)
