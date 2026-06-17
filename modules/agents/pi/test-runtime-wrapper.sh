#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
wrapper_source="$repo_root/modules/agents/pi/lib/_runtime-wrapper.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Fq -- "pkgs.nodejs" "$wrapper_source" \
  || fail "Pi wrapper must put Nix node on PATH before user/Homebrew node"

grep -Fq -- "pkgs.python311.withPackages (ps: [ ps.setuptools ])" "$wrapper_source" \
  || fail "Pi wrapper must use Python 3.11 with setuptools for node-gyp"

grep -Fq -- '--set DEVELOPER_DIR "/Library/Developer/CommandLineTools"' "$wrapper_source" \
  || fail "Pi wrapper must use CommandLineTools, not Xcode.app"

grep -Fq -- '--set PYTHON ${lib.escapeShellArg "${nodeGypPython}/bin/python3"}' "$wrapper_source" \
  || fail "Pi wrapper must export PYTHON for node-gyp"

grep -Fq -- 'updateExtensionsShim = lib.concatStringsSep "\n"' "$wrapper_source" \
  || fail "Pi update shim must avoid heredoc newline splitting before exec target"

printf 'PASS: Pi runtime wrapper keeps Nix node, Python 3.11+setuptools, and CLT wiring\n'
