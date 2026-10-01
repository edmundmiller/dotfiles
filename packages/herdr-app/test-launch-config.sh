#!/bin/bash
# Exercise Ghostty's real config loader with the generated Darwin fragments.
set -euo pipefail
app=$1
config_dir=$2
upstream_app=$3
test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT
mkdir -p "$test_home/.config/ghostty"
cp -L "$config_dir/"* "$test_home/.config/ghostty/"
herdr_config=$(/usr/bin/plutil -extract LSEnvironment.XDG_CONFIG_HOME raw "$app/Contents/Info.plist")

HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" \
  "$app/Contents/MacOS/ghostty" +list-keybinds > "$test_home/ghostty.conf"
HOME="$test_home" XDG_CONFIG_HOME="$herdr_config" \
  "$app/Contents/MacOS/ghostty" +list-keybinds > "$test_home/herdr.conf"

for config in ghostty herdr; do
  # This non-default binding proves the shared file was actually loaded.
  grep -Fx 'keybind = ctrl+shift+s=close_surface' "$test_home/$config.conf"
  for tab in {1..9}; do
    grep -Fx "keybind = super+$tab=goto_tab:$tab" "$test_home/$config.conf"
  done
  if grep -F 'text:\x03' "$test_home/$config.conf"; then
    echo "Unexpected tmux interrupt binding in $config" >&2
    exit 1
  fi
done
grep -Fx 'keybind = super+backquote=toggle_quick_terminal' "$test_home/ghostty.conf"
if grep -F '=toggle_quick_terminal' "$test_home/herdr.conf"; then
  echo 'Herdr must not claim the global quick-terminal shortcut' >&2
  exit 1
fi
/usr/bin/codesign --verify --deep --strict "$app"
/usr/bin/codesign -dv "$app" 2>&1 | grep -F '(adhoc,runtime)'
test "$(/usr/bin/plutil -extract SUVerifyUpdateBeforeExtraction raw "$app/Contents/Info.plist")" = true
test "$(/usr/bin/plutil -extract SUPublicEDKey raw "$app/Contents/Info.plist")" != \
  "$(/usr/bin/plutil -extract SUPublicEDKey raw "$upstream_app/Contents/Info.plist")"
echo 'Herdr and Ghostty launch configuration checks passed.'
