#!/usr/bin/env python3
"""Set a USB busylight/Luxafor status color.

Supports current JnyJny/busylight packages via busylight_core and keeps a small
fallback for the older busylight-for-humans Python API and CLI.
"""

from pathlib import Path
import shutil
import signal
import subprocess
import sys
import threading
import time

try:
    from busylight_core import Light as CoreLight
except Exception:
    CoreLight = None

try:
    from busylight.manager import LightManager
except Exception:
    LightManager = None

manager = None
keep_alive_thread = None
light = None
running = True

STATUS_COLORS = {
    "offline": None,
    "available": (0, 64, 0),
    "away": (64, 64, 0),
    "busy": (64, 0, 0),
    "dnd": (64, 0, 64),
    "ooo": (0, 0, 64),
    "meeting": (0, 30, 30),
    "call": (0, 30, 30),
    "calendar": (0, 30, 30),
    "presenting": (0, 30, 30),
}

STATUS_NAMES = {
    "available": "AVAILABLE (green)",
    "away": "AWAY (yellow)",
    "busy": "BUSY (red)",
    "dnd": "DO NOT DISTURB (magenta)",
    "ooo": "OUT OF OFFICE (blue)",
    "meeting": "IN A MEETING (cyan)",
    "call": "ON A CALL (cyan)",
    "calendar": "IN CALENDAR EVENT (cyan)",
    "presenting": "PRESENTING (cyan)",
}

# Kuando/Plenom Busylight devices (for example Busylight Omega) require a
# keep-alive for any lit state, otherwise they turn themselves off shortly after
# the controlling process exits. Keep all non-offline statuses alive.
KEEP_ALIVE_STATUSES = set(STATUS_COLORS) - {"offline"}


def signal_handler(signum, _frame):
    """Handle termination signals gracefully."""
    global running, keep_alive_thread, light, manager
    print(f"\nReceived signal {signum}, shutting down gracefully...")
    running = False

    if keep_alive_thread and keep_alive_thread.is_alive():
        keep_alive_thread.join(timeout=1)

    if light:
        try:
            light.off()
            print("Light turned off")
        except Exception:
            pass

    if manager:
        try:
            manager.off()
        except Exception:
            pass

    busylight = find_busylight_cli()
    if busylight:
        subprocess.run([busylight, "off"], check=False)

    sys.exit(0)


def keep_alive_worker(set_light):
    """Background thread to ensure light stays on (for meeting mode)."""
    global running
    while running:
        try:
            set_light()
            time.sleep(20)
        except Exception as e:
            if running:
                print(f"Keep-alive error: {e}")
            break


def cli_color(color):
    if color is None:
        return None
    names = {
        (0, 64, 0): "green",
        (64, 64, 0): "yellow",
        (64, 0, 0): "red",
        (64, 0, 64): "magenta",
        (0, 0, 64): "blue",
        (0, 30, 30): "cyan",
    }
    return names.get(color, "#{:02x}{:02x}{:02x}".format(*color))


def find_busylight_cli():
    sibling = Path(sys.executable).with_name("busylight")
    if sibling.exists():
        return str(sibling)
    return shutil.which("busylight")


def run_keep_alive(status, set_light):
    global keep_alive_thread
    if status not in KEEP_ALIVE_STATUSES:
        return

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    print("Keep-alive running...")
    keep_alive_thread = threading.Thread(target=keep_alive_worker, args=(set_light,), daemon=True)
    keep_alive_thread.start()
    print("Press Ctrl+C to turn off the light and exit")
    try:
        while running:
            time.sleep(1)
    except KeyboardInterrupt:
        signal_handler(signal.SIGINT, None)


def run_with_core(status, color):
    global light
    lights = CoreLight.all_lights(reset=True, exclusive=True)
    if not lights:
        print("No busylight devices found!")
        sys.exit(1)

    light = lights[0]
    print(f"Found busylight: {light.name}")

    if status == "offline":
        light.off()
        print("Busylight turned off (Offline)")
        return

    def set_light():
        light.on(color)

    set_light()
    print(f"Busylight set to {STATUS_NAMES[status]}: {light.name}")
    run_keep_alive(status, set_light)


def run_with_legacy_manager(status, color):
    global manager, light
    manager = LightManager()

    if not manager.lights:
        print("No busylight devices found!")
        sys.exit(1)

    light = manager.lights[0]
    print(f"Found busylight: {light.name}")

    if status == "offline":
        light.off()
        print("Busylight turned off (Offline)")
        return

    def set_light():
        light.on(color)

    set_light()
    print(f"Busylight set to {STATUS_NAMES[status]}: {light.name}")
    run_keep_alive(status, set_light)


def run_with_cli(status, color):
    busylight = find_busylight_cli()
    if not busylight:
        raise RuntimeError("No supported busylight API or CLI is available")

    if status == "offline":
        subprocess.run([busylight, "off"], check=True)
        print("Busylight turned off (Offline)")
        return

    color_arg = cli_color(color)

    def set_light():
        # The installed Nix package currently expects integer percentages here;
        # newer upstream docs describe 0.0-1.0. If this changes, the core API
        # path above should continue to work and keep us off CLI flag churn.
        subprocess.run([busylight, "--dim", "50", "on", color_arg], check=True)

    set_light()
    print(f"Busylight set to {STATUS_NAMES[status]} via CLI")
    run_keep_alive(status, set_light)


def main():
    global light, manager

    if len(sys.argv) < 2:
        print("Usage: busylight-status.py <status>")
        print("Status options: offline, available, away, busy, dnd, ooo, meeting, call, calendar, presenting")
        sys.exit(1)

    status = sys.argv[1].lower()
    if status not in STATUS_COLORS:
        print(f"Unknown status: {status}")
        print("Valid options: offline, available, away, busy, dnd, ooo, meeting, call, calendar, presenting")
        sys.exit(1)

    color = STATUS_COLORS[status]

    try:
        if CoreLight is not None:
            run_with_core(status, color)
        elif LightManager is not None:
            run_with_legacy_manager(status, color)
        else:
            run_with_cli(status, color)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
    finally:
        if light and status in KEEP_ALIVE_STATUSES:
            try:
                light.off()
            except Exception:
                pass
        light = None
        manager = None


if __name__ == "__main__":
    main()
