#!/usr/bin/env bash
# Validate the OMP LSP configuration rendered for each Darwin host.
set -euo pipefail

repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"

declare -A users=(
    ["MacTraitor-Pro"]=emiller
    [Seqeratop]=edmundmiller
)

for host in "${!users[@]}"; do
    attr="path:$repo_root#darwinConfigurations.${host}.config.home-manager.users.${users[$host]}.home.file.\".omp/agent/lsp.json\".source"
    lsp_config="$(nix build --no-link --print-out-paths "$attr")"

    OMP_LSP_CONFIG="$lsp_config" OMP_LSP_HOST="$host" python3 - <<'PY'
import json
import os
from pathlib import Path

config = json.loads(Path(os.environ["OMP_LSP_CONFIG"]).read_text())
host = os.environ["OMP_LSP_HOST"]

assert set(config) == {"nextflow", "typescript-language-server"}, host

effect = config["typescript-language-server"]
assert effect["args"] == ["--lsp", "--stdio"], effect
assert effect["command"].endswith("/bin/effect-tsgo"), effect
assert os.access(effect["command"], os.X_OK), effect

nextflow = config["nextflow"]
assert nextflow["command"].endswith("/bin/nextflow-language-server"), nextflow
assert os.access(nextflow["command"], os.X_OK), nextflow
PY
done
