#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# [tool.uv]
# exclude-newer = "2026-11-06T00:00:00Z"
# ///
"""Check a local or served done bundle against canonical source and its contract."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "skills/catalog/done"


def manifest(bundle: Path) -> dict[str, str]:
    return {
        str(path.relative_to(bundle)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(bundle.rglob("*"))
        if path.is_file()
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path, help="materialized done directory")
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    expected = manifest(SOURCE)
    actual = manifest(bundle)
    drift = sorted(
        name for name in expected.keys() | actual.keys()
        if expected.get(name) != actual.get(name)
    )
    if drift:
        print("done bundle differs from canonical: " + ", ".join(drift), file=sys.stderr)
        return 1
    if not shutil.which("jj"):
        print("jj is required to verify the working-jj contract", file=sys.stderr)
        return 1
    result = subprocess.run(
        [sys.executable, "-m", "unittest", "tests.test_done_closeout"],
        cwd=ROOT,
        env={**os.environ, "DONE_SKILL_DIR": str(bundle), "PYTHONDONTWRITEBYTECODE": "1"},
    )
    if result.returncode:
        return result.returncode
    print(json.dumps({"bundle": str(bundle), "sha256": actual}, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
