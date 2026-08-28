# shellcheck shell=bash
set -euo pipefail

: "${CODEX_HOME_ASSISTANT_SECRET_REFERENCE:?missing Home Assistant 1Password reference}"

op_bin="${OP_BIN:-op}"
codex_bin="${CODEX_BIN:-codex}"
export HASS_TOKEN="$CODEX_HOME_ASSISTANT_SECRET_REFERENCE"
unset CODEX_HOME_ASSISTANT_SECRET_REFERENCE

exec "$op_bin" run -- "$codex_bin" "$@"
