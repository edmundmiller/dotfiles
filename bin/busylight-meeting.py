#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
# "busylight-for-humans"
# ]
# ///

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Busylight Meeting
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🩵
# @raycast.packageName busylight

# Documentation:
# @raycast.description Turn busylight on to red
# @raycast.author edmundmiller
# @raycast.authorURL https://raycast.com/edmundmiller

import time
import threading
import signal
import sys
from busylight.manager import LightManager

# Global variables for cleanup
manager = None
keep_alive_thread = None
light = None
running = True

def signal_handler(signum, frame):
    """Handle termination signals gracefully"""
    global running, keep_alive_thread, light, manager
    print(f"\nReceived signal {signum}, shutting down gracefully...")
    running = False

    if keep_alive_thread and keep_alive_thread.is_alive():
        keep_alive_thread.join(timeout=1)

    if light:
        try:
            light.off()
            print("Light turned off")
        except:
            pass

    if manager:
        try:
            manager.off()
        except:
            pass

    sys.exit(0)

def keep_alive_worker():
    """Background thread to ensure light stays on (backup for library keep-alive)"""
    global running, light
    while running:
        try:
            if light and running:
                # Send a gentle keep-alive by re-setting the same color
                light.on((0, 30, 30))
            time.sleep(20)  # Refresh every 20 seconds (well within 30s timeout)
        except Exception as e:
            if running:  # Only log if we're still supposed to be running
                print(f"Keep-alive error: {e}")
            break

# Register signal handlers for graceful shutdown
signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

try:
    # Initialize the light manager (recommended for Kuando devices)
    manager = LightManager()

    if manager.lights:
        light = manager.lights[0]  # Get the first available light

        # Set light to cyan color
        light.on((0, 30, 30))

        print(f"Busylight turned on: {light.name}")
        print("Library keep-alive + backup thread running...")

        # Start backup keep-alive thread as failsafe
        keep_alive_thread = threading.Thread(target=keep_alive_worker, daemon=True)
        keep_alive_thread.start()

        # Keep the script running to maintain the light
        print("Press Ctrl+C to turn off the light and exit")
        try:
            while running:
                time.sleep(1)
        except KeyboardInterrupt:
            signal_handler(signal.SIGINT, None)
    else:
        print("No busylight devices found!")

except Exception as e:
    print(f"Error: {e}")
    signal_handler(signal.SIGTERM, None)
