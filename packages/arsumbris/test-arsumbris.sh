#!/usr/bin/env bash
set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/arsumbris.sh"
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
export HOME="$temporary/home with spaces"
mkdir -p "$HOME"

bash "$script" --help >"$temporary/output"
grep -q 'Usage: arsumbris setup | dev' "$temporary/output"
test ! -e "$HOME/arsumbris"

if bash "$script" setup unexpected >"$temporary/output" 2>&1; then
  echo 'Extra arguments must fail before setup' >&2
  exit 1
fi
grep -q 'expected exactly one subcommand' "$temporary/output"
test ! -e "$HOME/arsumbris"

if bash "$script" dev >"$temporary/output" 2>&1; then
  echo 'Launching an absent installation must fail' >&2
  exit 1
fi
grep -q 'run arsumbris setup first' "$temporary/output"

if [[ "$(uname -s)" == Darwin ]] && /usr/bin/xcode-select -p >/dev/null 2>&1; then
  # A conflict late in the repo list must stop setup before earlier repos clone.
  mkdir -p "$HOME/arsumbris/au-defaults"
  printf 'keep my files\n' >"$HOME/arsumbris/au-defaults/precious.txt"
  if bash "$script" setup >"$temporary/output" 2>&1; then
    echo 'An existing non-repository destination must be preserved' >&2
    exit 1
  fi
  grep -q 'preserving .*au-defaults' "$temporary/output"
  test "$(cat "$HOME/arsumbris/au-defaults/precious.txt")" = 'keep my files'
  test ! -e "$HOME/arsumbris/arsumbris"
  test ! -e "$HOME/.arsumbris"
else
  echo 'SKIP: destination preflight needs macOS Command Line Tools'
fi

echo 'Ars Umbris CLI safety checks passed'
