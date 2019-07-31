#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch Polybar, using default config location ~/.config/polybar/config
if type "xrandr"; then
	for m in $(xrandr --query | grep " primary" | cut -d" " -f1); do
		MONITOR=$m polybar --reload top &
	done
else
	polybar --reload top &
fi
echo "Polybar launched..."
