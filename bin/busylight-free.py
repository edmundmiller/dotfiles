#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
# "busylight-for-humans"
# ]
# ///

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Busylight Free
# @raycast.mode Silent

# Optional parameters:
# @raycast.icon 🟢
# @raycast.packageName busylight

# Documentation:
# @raycast.description Turn busylight on to green
# @raycast.author edmundmiller
# @raycast.authorURL https://raycast.com/edmundmiller

# busylight -d 30 on red
from busylight.lights import Light

light = Light.first_light()

# Set light to red at 25% brightness
# Full red is (255, 0, 0), so 25% is (64, 0, 0)
light.on((0, 64, 0))

# Uncomment the line below if you want to turn it off immediately
# light.off()
