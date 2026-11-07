"""Compile done's CLI entrypoints once for native integration tests."""

import atexit
from functools import cache
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


SKILL = Path(
    os.environ.get(
        "DONE_SKILL_DIR", Path(__file__).resolve().parents[1] / "skills/catalog/done"
    )
)
_build = tempfile.TemporaryDirectory(prefix="done-bend-tests-")
atexit.register(_build.cleanup)


@cache
def binary(name: str) -> str:
    bend = shutil.which("bend")
    if not bend:
        raise RuntimeError("done tests require Bend 2.0.40+ and clang 14+ on PATH")
    output = Path(_build.name) / name
    subprocess.run(
        [bend, str(SKILL / "scripts" / f"{name}.bend"), "-o", str(output)],
        check=True,
        capture_output=True,
        text=True,
    )
    return str(output)
