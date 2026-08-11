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
import subprocess
import tempfile
from pathlib import Path
config = json.loads(Path(os.environ["OMP_LSP_CONFIG"]).read_text())
host = os.environ["OMP_LSP_HOST"]

assert set(config) == {"nextflow", "typescript-language-server"}, host

typescript = config["typescript-language-server"]
assert typescript["args"] == ["--stdio"], typescript
assert typescript["command"].endswith("/bin/omp-typescript-language-server"), typescript
assert os.access(typescript["command"], os.X_OK), typescript
for package, expected_code, expected_output in (
    ({"devDependencies": {"typescript": "^5"}}, 0, ""),
    ({"scripts": {"check": "echo @effect/tsgo"}}, 0, ""),
    ({"devDependencies": {"@effect/tsgo": "0.36.4"}}, 2, "Usage of lsp:"),
):
    with tempfile.TemporaryDirectory() as project:
        Path(project, "package.json").write_text(json.dumps(package))
        result = subprocess.run(
            [typescript["command"], "--version"],
            cwd=project,
            capture_output=True,
            text=True,
            timeout=10,
        )
        assert result.returncode == expected_code, result
        assert expected_output in result.stderr, result

nextflow = config["nextflow"]
assert nextflow["command"].endswith("/bin/nextflow-language-server"), nextflow
assert os.access(nextflow["command"], os.X_OK), nextflow
PY
done
