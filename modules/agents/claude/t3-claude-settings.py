#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# ///
"""Sync existing T3 Claude provider paths without owning other T3 settings."""

import json
import os
from pathlib import Path
import stat
import sys
import tempfile


def sync_t3_claude_settings(target: Path, binary_path: str) -> None:
    """Update all Claude instances; leave absent T3 settings and providers alone."""
    if not target.exists():
        return
    settings = json.loads(target.read_text(encoding="utf-8"))
    changed = False
    for instance_id, instance in settings.get("providerInstances", {}).items():
        if instance.get("driver", instance_id) != "claudeAgent":
            continue
        config = instance.setdefault("config", {})
        if config.get("binaryPath") != binary_path:
            config["binaryPath"] = binary_path
            changed = True
    if not changed:
        return
    # Replace atomically so T3 never reads partially written JSON.
    descriptor, temporary = tempfile.mkstemp(dir=target.parent, prefix=".t3-claude-")
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            output.write(json.dumps(settings, indent=2) + "\n")
            os.fchmod(output.fileno(), stat.S_IMODE(target.stat().st_mode))
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    sync_t3_claude_settings(Path(sys.argv[1]), sys.argv[2])
