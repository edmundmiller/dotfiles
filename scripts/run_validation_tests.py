"""Run independent unittest modules in bounded, isolated child processes."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def run_module(module):
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="validation-module-") as directory:
        root = Path(directory)
        for name in ("home", "tmp"):
            (root / name).mkdir()
        result = subprocess.run(
            [sys.executable, "-m", "unittest", "-v", module],
            env=os.environ | {"HOME": str(root / "home"), "TMPDIR": str(root / "tmp")},
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
    return module, result.returncode, result.stdout, time.monotonic() - started


def main():
    cores = int(os.environ.get("NIX_BUILD_CORES", "0")) or os.cpu_count() or 1
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=int, choices=range(1, 5), default=min(4, cores))
    parser.add_argument("modules", nargs="+")
    args = parser.parse_args()
    started = time.monotonic()
    failed = 0
    with ThreadPoolExecutor(max_workers=args.jobs) as executor:
        pending = [executor.submit(run_module, module) for module in args.modules]
        for future in as_completed(pending):
            module, code, output, seconds = future.result()
            failed += code != 0
            print(f"=== {module}: {'FAIL' if code else 'PASS'} ({seconds:.3f}s) ===")
            print(output, end="", flush=True)
    print(f"{len(args.modules)} modules, {failed} failed, {args.jobs} workers, "
          f"{time.monotonic() - started:.3f}s elapsed", flush=True)
    return int(failed != 0)


if __name__ == "__main__":
    sys.exit(main())
