#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys
from pathlib import Path

args = sys.argv[1:]
if args:
    path = args[0].split("::", 1)[0]
    if path and not Path(path).exists():
        print(f"Missing test path: {path}", file=sys.stderr)
        raise SystemExit(2)

if shutil.which("uv") and (Path("uv.lock").exists() or Path("pyproject.toml").exists()):
    cmd = ["uv", "run", "pytest", *args]
else:
    cmd = [sys.executable, "-m", "pytest", *args]

if not args:
    cmd.append("-q")
elif not any(arg.startswith("-q") or arg.startswith("-v") for arg in args):
    cmd.append("-q")

os.execvp(cmd[0], cmd)
