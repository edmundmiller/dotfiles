#!/usr/bin/env bash
# Run inside nix develop .#display-devices with agent-browser on PATH.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$project_dir/../../.." && pwd)"
output_dir="${1:?pass an output directory for reviewed preview screenshots}"
mkdir -p "$output_dir"
output_dir="$(realpath "$output_dir")"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

python3 - "$repo_dir" "$scratch" <<'PY'
import json
from pathlib import Path
import shutil
import sys
from zoneinfo import ZoneInfo
repo, scratch = map(Path, sys.argv[1:])
sys.path.insert(0, str(repo / "packages/displayctl"))
from test_tasks import fixture, display, NOW
for state in ("normal", "stale", "empty", "error", "unavailable", "overloaded", "real_scale"):
    project = scratch / state
    shutil.copytree(repo / "config/trmnl/agent-message/src", project / "src")
    payload = display._task_payload(fixture(state), NOW, ZoneInfo("America/Chicago"), 900)
    (project / ".trmnlp.yml").write_text(json.dumps({"variables": payload}))
PY

for state in normal stale empty error unavailable overloaded real_scale; do
  trmnlp build --dir "$scratch/$state" --quiet
done

# TRMNLP's width option only resizes the viewport, not the device canvas.
# Set the actual framework model class so X is not an OG image in a large PNG.
python3 - "$scratch" <<'PY'
from pathlib import Path
import sys
for page in Path(sys.argv[1]).glob("*/_build/*.html"):
    text = page.read_text()
    page.with_name(page.stem + "-x.html").write_text(text.replace('class="screen"', 'class="screen screen--v2 screen--1x"'))
PY

for model in og x; do
  if [[ "$model" == og ]]; then
    agent-browser --session display-tasks set viewport 800 480 >/dev/null
    suffix=""
  else
    agent-browser --session display-tasks set viewport 1040 780 >/dev/null
    suffix="-x"
  fi
  for state in normal stale empty error unavailable overloaded real_scale; do
    for view in full half_horizontal half_vertical quadrant; do
      agent-browser --session display-tasks open "file://$scratch/$state/_build/$view$suffix.html" >/dev/null
      agent-browser --session display-tasks wait --load networkidle >/dev/null
      agent-browser --session display-tasks eval '
        const view = document.querySelector(".view");
        const bounds = view.getBoundingClientRect();
        const screen = document.querySelector(".screen").getBoundingClientRect();
        if (screen.right > innerWidth + 1 || screen.bottom > innerHeight + 1) throw Error("Canvas exceeds physical viewport");
        const leaves = [...view.querySelectorAll("span")].filter(e => e.textContent.trim());
        if (!leaves.length || getComputedStyle(view).display === "block") throw Error("Framework missing");
        for (const leaf of leaves) {
          const r = leaf.getBoundingClientRect();
          if (r.width <= 0 || r.height <= 0 || r.left < bounds.left - 1 || r.right > bounds.right + 1 || r.bottom > bounds.bottom + 1) {
            throw Error("Clipped content: " + leaf.textContent);
          }
        }
        if (!view.textContent.includes("Stale after") || !view.textContent.includes("As of")) throw Error("Missing freshness");
        true
      ' >/dev/null
      agent-browser --session display-tasks screenshot "$output_dir/$state-$model-$view.png" >/dev/null
    done
  done
done
agent-browser --session display-tasks close >/dev/null
printf '%s\n' 'Task preview checks passed: seven states, four views, OG/X actual canvases; no device writes.'
