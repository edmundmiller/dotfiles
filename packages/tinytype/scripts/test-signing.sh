#!/usr/bin/env bash
# Opt-in macOS regression: changed binaries must satisfy the first build's identity.
set -euo pipefail
: "${TINYTYPE_SIGNING_IDENTITY:?Set the SHA-1 of an existing Keychain signing identity}"
if ! [[ "$TINYTYPE_SIGNING_IDENTITY" =~ ^[[:xdigit:]]{40}$ ]]; then
  echo "A certificate identity is required; ad-hoc signing cannot preserve TCC grants." >&2
  exit 1
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
temporary="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/tinytype-signing-test.XXXXXX")"
trap '/bin/rm -rf "$temporary"' EXIT
mkdir -p "$temporary/engine/node_modules" "$temporary/models"
printf '{}\n' > "$temporary/engine/package.json"
touch "$temporary/engine/tinyfix-worker.mjs"
for version in 1 2; do
  printf 'int main(void) { return %s; }\n' "$version" > "$temporary/program.c"
  /usr/bin/clang "$temporary/program.c" -o "$temporary/program"
  bash "$root/scripts/bundle-app.sh" "$temporary/program" "$temporary/program" \
    /usr/bin/true "$temporary/engine" "$temporary/models" "$temporary/version-$version.app"
done
for executable in Contents/MacOS/tinytype Contents/Resources/focused-text; do
  first="$temporary/version-1.app/$executable"
  second="$temporary/version-2.app/$executable"
  requirement="$(/usr/bin/codesign -d -r- "$first" 2>&1 | sed -n 's/^designated => //p')"
  test -n "$requirement"
  case "$requirement" in
  *cdhash*) echo "TinyType signing regressed to an executable-hash requirement" >&2; exit 1 ;;
  esac
  if /usr/bin/cmp -s "$first" "$second"; then
    echo "Signing test did not produce changed executable bytes" >&2
    exit 1
  fi
  /usr/bin/codesign --verify --strict -R="$requirement" "$second"
done
printf 'PASS: changed app and helper satisfy the original certificate-based requirements. This does not grant or modify macOS permissions.\n'
