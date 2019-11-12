#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch Polybar, using default config location ~/.config/polybar/config
PRIMARY=$(xrandr --query | grep " primary" | cut -d" " -f1)

if type "xrandr"; then
	for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
		if [ $m == $PRIMARY ]; then
			MONITOR=$m polybar --reload main -c ~/.dotfiles/config/polybar/config &
		else
			MONITOR=$m polybar --reload side -c ~/.dotfiles/config/polybar/config &
		fi
	done
else
	polybar --reload main &
fi
echo "Polybar launched..."
