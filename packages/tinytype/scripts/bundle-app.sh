#!/usr/bin/env bash
# Assemble the same app layout for local and Nix builds without installing it.
set -euo pipefail
if [ "$#" -ne 6 ]; then
  echo "Usage: bundle-app.sh BINARY HELPER NODE ENGINE MODELS OUTPUT.app" >&2
  exit 2
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
app="$6"
if [ -e "$app" ]; then
  echo "TinyType output already exists: $app" >&2
  exit 1
fi
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/engine" "$app/Contents/Resources/models"
cp "$root/app/Info.plist" "$app/Contents/Info.plist"
cp "$root/app/TinyFix.icns" "$root/app/TinyFixTemplate.png" \
  "$root/app/TinyFixTemplate@2x.png" "$app/Contents/Resources/"
install -m755 "$1" "$app/Contents/MacOS/tinytype"
install -m755 "$2" "$app/Contents/Resources/focused-text"
install -m755 "$3" "$app/Contents/Resources/node"
cp "$4/tinyfix-worker.mjs" "$4/package.json" "$app/Contents/Resources/engine/"
cp -RL "$4/node_modules" "$app/Contents/Resources/engine/"
cp -RL "$5/." "$app/Contents/Resources/models/"
chmod -R u+w "$app"
# Nix and unsigned previews stay ad-hoc. The dev installer requires an explicit
# certificate, with stable identifiers for every executable that TCC can attribute.
identity="${TINYTYPE_SIGNING_IDENTITY:--}"
if [ "$identity" != - ]; then
  printf '%s\n' "$identity" > "$app/Contents/Resources/tinytype-signing-identity"
fi
for name in node focused-text; do
  /usr/bin/codesign --force --timestamp=none --sign "$identity" \
    --identifier "dev.edmundmiller.tinytype.$name" "$app/Contents/Resources/$name"
done
/usr/bin/codesign --force --timestamp=none --sign "$identity" \
  --identifier dev.edmundmiller.tinytype "$app"
/usr/bin/codesign --verify --deep --strict "$app"
printf 'Built %s\n' "$app"
