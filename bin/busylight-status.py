#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
# "busylight-for-humans"
# ]
# ///

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Busylight Status
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🚦
# @raycast.packageName busylight
# @raycast.argument1 { "type": "dropdown", "placeholder": "Status", "data": [{"title": "🔴 Offline", "value": "offline"}, {"title": "✅ Available", "value": "available"}, {"title": "🟡 Away", "value": "away"}, {"title": "❌ Busy", "value": "busy"}, {"title": "🟣 Do Not Disturb", "value": "dnd"}, {"title": "🔵 Out of Office", "value": "ooo"}, {"title": "🟦 In a Meeting", "value": "meeting"}, {"title": "🟦 On a Call", "value": "call"}, {"title": "🟦 In Calendar Event", "value": "calendar"}, {"title": "🟦 Presenting", "value": "presenting"}] }

# Documentation:
# @raycast.description Set busylight status - Free (green), Meeting (cyan), or Off
# @raycast.author edmundmiller
# @raycast.authorURL https://raycast.com/edmundmiller

import sys
import time
import threading
import signal
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

def keep_alive_worker(color):
    """Background thread to ensure light stays on (for meeting mode)"""
    global running, light
    while running:
        try:
            if light and running:
                # Send a gentle keep-alive by re-setting the same color
                light.on(color)
            time.sleep(20)  # Refresh every 20 seconds (well within 30s timeout)
        except Exception as e:
            if running:  # Only log if we're still supposed to be running
                print(f"Keep-alive error: {e}")
            break

def main():
    global manager, light, keep_alive_thread, running

    # Get the status argument
    if len(sys.argv) < 2:
        print("Usage: busylight-status.py <status>")
        print("Status options: offline, available, away, busy, dnd, ooo, meeting, call, calendar, presenting")
        sys.exit(1)

    status = sys.argv[1].lower()

    # Define colors for each status
    status_colors = {
        'offline': None,  # Turn off
        'available': (0, 64, 0),     # Green
        'away': (64, 64, 0),         # Yellow
        'busy': (64, 0, 0),          # Red
        'dnd': (64, 0, 64),          # Magenta
        'ooo': (0, 0, 64),           # Blue
        'meeting': (0, 30, 30),      # Cyan
        'call': (0, 30, 30),         # Cyan
        'calendar': (0, 30, 30),     # Cyan
        'presenting': (0, 30, 30)    # Cyan
    }

    # Statuses that need keep-alive (longer duration activities)
    keep_alive_statuses = {'busy', 'dnd', 'meeting', 'call', 'calendar', 'presenting'}

    try:
        # Initialize the light manager
        manager = LightManager()

        if not manager.lights:
            print("No busylight devices found!")
            sys.exit(1)

        light = manager.lights[0]  # Get the first available light

        if status not in status_colors:
            print(f"Unknown status: {status}")
            print("Valid options: offline, available, away, busy, dnd, ooo, meeting, call, calendar, presenting")
            sys.exit(1)

        if status == "offline":
            light.off()
            print("Busylight turned off (Offline)")
            return

        color = status_colors[status]
        light.on(color)

        status_names = {
            'available': 'AVAILABLE (green)',
            'away': 'AWAY (yellow)',
            'busy': 'BUSY (red)',
            'dnd': 'DO NOT DISTURB (magenta)',
            'ooo': 'OUT OF OFFICE (blue)',
            'meeting': 'IN A MEETING (cyan)',
            'call': 'ON A CALL (cyan)',
            'calendar': 'IN CALENDAR EVENT (cyan)',
            'presenting': 'PRESENTING (cyan)'
        }

        print(f"Busylight set to {status_names[status]}: {light.name}")

        # Only use keep-alive for longer duration statuses
        if status in keep_alive_statuses:
            # Register signal handlers for graceful shutdown
            signal.signal(signal.SIGINT, signal_handler)
            signal.signal(signal.SIGTERM, signal_handler)

            print("Library keep-alive + backup thread running...")

            # Start backup keep-alive thread as failsafe
            keep_alive_thread = threading.Thread(target=keep_alive_worker, args=(color,), daemon=True)
            keep_alive_thread.start()

            # Keep the script running to maintain the light
            print("Press Ctrl+C to turn off the light and exit")
            try:
                while running:
                    time.sleep(1)
            except KeyboardInterrupt:
                signal_handler(signal.SIGINT, None)
        # For short-term statuses (available, away, ooo), just set and exit

    except Exception as e:
        print(f"Error: {e}")
        if status in keep_alive_statuses:
            signal_handler(signal.SIGTERM, None)
        sys.exit(1)

if __name__ == "__main__":
    main()
