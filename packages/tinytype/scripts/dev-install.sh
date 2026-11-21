#!/usr/bin/env bash
# Build and certificate-sign before stopping the installed app. Never reset TCC.
set -euo pipefail
if [ "$#" -ne 0 ]; then
  echo "Usage: TINYTYPE_SIGNING_IDENTITY=<Keychain SHA-1> bash scripts/dev-install.sh" >&2
  exit 2
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
app="$HOME/Applications/TinyType.app"
marker="$app/Contents/Resources/tinytype-signing-identity"
identity="${TINYTYPE_SIGNING_IDENTITY:-}"
if [ -z "$identity" ] && [ -f "$marker" ]; then identity="$(cat "$marker")"; fi
identities="$(/usr/bin/security find-identity -v -p codesigning | sed -En 's/^ *[0-9]+\) ([[:xdigit:]]{40}) ".*/\1/p')"
if [ -z "$identity" ] && [ "$(printf '%s\n' "$identities" | sed '/^$/d' | wc -l | tr -d ' ')" = 1 ]; then
  identity="$identities"
fi
if ! [[ "$identity" =~ ^[[:xdigit:]]{40}$ ]] || ! printf '%s\n' "$identities" | grep -Fxiq "$identity"; then
  echo "TinyType needs a valid Keychain signing identity. Set TINYTYPE_SIGNING_IDENTITY to a SHA-1 from security find-identity -v -p codesigning. No app was replaced." >&2
  exit 1
fi
export TINYTYPE_SIGNING_IDENTITY="$identity"
if [ -L "$app" ] || { [ -e "$app" ] && [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null || true)" != dev.edmundmiller.tinytype ]; }; then
  echo "TinyType refuses to replace an unrelated app or a symlink at $app" >&2
  exit 1
fi
mkdir -p "$HOME/Applications"
stage="$(/usr/bin/mktemp -d "$HOME/Applications/.tinytype-dev.XXXXXX")"
cleanup() {
  if [ -d "$stage/previous.app" ] && [ ! -e "$app" ]; then
    /bin/mv "$stage/previous.app" "$app" || return 1
  fi
  /bin/rm -rf "$stage"
}
trap cleanup EXIT
bash "$root/scripts/build-app.sh" "$stage/TinyType.app"
requirement="identifier \"dev.edmundmiller.tinytype\" and certificate leaf = H\"$identity\""
/usr/bin/codesign --verify --deep --strict -R="$requirement" "$stage/TinyType.app"
/usr/bin/codesign --verify --strict \
  -R="identifier \"dev.edmundmiller.tinytype.focused-text\" and certificate leaf = H\"$identity\"" \
  "$stage/TinyType.app/Contents/Resources/focused-text"

# A running playground is cleared by this explicitly requested dev restart.
# Wait for orderly shutdown; a hung process leaves the installed app unchanged.
pid=""
for candidate in $(/usr/bin/pgrep -x tinytype || true); do
  if [ "$(/bin/ps -p "$candidate" -o comm=)" = "$app/Contents/MacOS/tinytype" ]; then pid="$candidate"; fi
done
if [ -n "$pid" ]; then
  /usr/bin/osascript -e 'tell application id "dev.edmundmiller.tinytype" to quit'
  for _ in {1..50}; do
    if ! /bin/kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 0.2
  done
  if /bin/kill -0 "$pid" 2>/dev/null; then
    echo "TinyType did not quit. The installed app was left unchanged." >&2
    exit 1
  fi
fi
if [ -e "$app" ]; then /bin/mv "$app" "$stage/previous.app"; fi
/bin/mv "$stage/TinyType.app" "$app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
/usr/bin/open "$app"
printf 'Installed and restarted %s with signing identity %s\n' "$app" "$identity"
printf 'First migration from ad-hoc signing: remove the stale TinyType permission row, then use Set up Accessibility. Later rebuilds keep the signing identity.\n'
