#!/usr/bin/env python3
"""Mirror LookAway meeting detection to the USB Busylight.

LookAway does not currently expose meeting start/end as automation triggers, but it
logs high-engagement activity transitions in its debug log. This daemon tails that
log and runs the existing busylight-status.py script when LookAway detects a
meeting and when that meeting ends.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
DEFAULT_LOG = HOME / "Library/Application Support/LookAway/Logs/LookAway-DebugLogs.txt"
DEFAULT_BUSY_SCRIPT = HOME / ".config/dotfiles/bin/busylight-status.py"

LOG_PATH = Path(os.environ.get("LOOKAWAY_LOG", str(DEFAULT_LOG))).expanduser()
BUSYLIGHT_SCRIPT = Path(os.environ.get("BUSYLIGHT_STATUS_SCRIPT", str(DEFAULT_BUSY_SCRIPT))).expanduser()
PYTHON = os.environ.get("BUSYLIGHT_PYTHON", sys.executable)
START_STATUS = os.environ.get("BUSYLIGHT_MEETING_START_STATUS", "meeting")
END_STATUS = os.environ.get("BUSYLIGHT_MEETING_END_STATUS", "available")
POLL_INTERVAL = float(os.environ.get("LOOKAWAY_BUSY_LIGHT_POLL_INTERVAL", "1"))

MEETING_START_MARKERS = (
    "HE Activity: Request received to pause with reason: meeting",
    "Meeting detected on ",
)
MEETING_END_MARKERS = (
    "HE Activity: Resuming pause with reason: meeting",
    "Meeting not detected",
)

running = True
meeting_active = False
meeting_process: subprocess.Popen[str] | None = None


def log(message: str) -> None:
    print(message, flush=True)


def run_status(status: str, *, keep_alive: bool) -> subprocess.Popen[str] | None:
    if not BUSYLIGHT_SCRIPT.exists():
        log(f"Busylight script not found: {BUSYLIGHT_SCRIPT}")
        return None

    cmd = [PYTHON, str(BUSYLIGHT_SCRIPT), status]
    log(f"Running: {' '.join(cmd)}")
    if keep_alive:
        return subprocess.Popen(cmd)

    subprocess.run(cmd, check=False, timeout=15)
    return None


def stop_meeting_process() -> None:
    global meeting_process
    if meeting_process is None:
        return

    if meeting_process.poll() is None:
        log("Stopping meeting keep-alive process")
        meeting_process.terminate()
        try:
            meeting_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            meeting_process.kill()
            meeting_process.wait(timeout=5)
    meeting_process = None


def meeting_started() -> None:
    global meeting_active, meeting_process
    if meeting_active:
        return
    meeting_active = True
    stop_meeting_process()
    meeting_process = run_status(START_STATUS, keep_alive=True)


def meeting_ended() -> None:
    global meeting_active, meeting_process
    if not meeting_active:
        return
    meeting_active = False
    stop_meeting_process()
    if END_STATUS and END_STATUS.lower() != "none":
        # Some devices, notably Busylight Omega, require keep-alives for any
        # lit state. Keep the post-meeting status process alive unless the
        # desired state is explicitly off/offline.
        keep_alive = END_STATUS.lower() not in {"off", "offline"}
        meeting_process = run_status(END_STATUS, keep_alive=keep_alive)


def handle_line(line: str) -> None:
    if any(marker in line for marker in MEETING_START_MARKERS):
        meeting_started()
    elif any(marker in line for marker in MEETING_END_MARKERS):
        meeting_ended()


def shutdown(_signum: int | None = None, _frame: object | None = None) -> None:
    global running
    running = False
    meeting_ended()


def tail_log() -> None:
    inode: int | None = None
    position = 0

    while running:
        try:
            stat = LOG_PATH.stat()
        except FileNotFoundError:
            time.sleep(POLL_INTERVAL)
            continue

        if inode != stat.st_ino:
            inode = stat.st_ino
            # Start at EOF so old meetings in historical logs do not replay.
            position = stat.st_size
            log(f"Watching {LOG_PATH}")

        if stat.st_size < position:
            position = 0

        with LOG_PATH.open("r", encoding="utf-8", errors="replace") as fh:
            fh.seek(position)
            for line in fh:
                handle_line(line.rstrip("\n"))
            position = fh.tell()

        time.sleep(POLL_INTERVAL)


def main() -> int:
    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)
    log("LookAway busylight monitor starting")
    try:
        tail_log()
    finally:
        shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
