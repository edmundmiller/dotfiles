#!/usr/bin/env sh
set -eu

if [ "$#" -lt 1 ]; then
  echo "usage: sh scripts/run-targeted-nf-test.sh path/to/main.nf.test [nf-test args...]" >&2
  exit 2
fi

target=$1
shift

if [ ! -f "$target" ]; then
  echo "Missing nf-test file: $target" >&2
  exit 2
fi

if ! command -v nf-test >/dev/null 2>&1; then
  echo "nf-test not found on PATH" >&2
  exit 127
fi

exec nf-test test "$target" "$@"
