#!/usr/bin/env python3
"""Register declared SSH machines through hc without replacing runtime state."""

import argparse
import json
from pathlib import Path
import subprocess


def reconcile_native_machines(core, machines):
    """Add missing machines; refuse name conflicts and preserve all other entries."""

    def run_core(*args):
        result = subprocess.run(
            [core, "--json", "machine", *args],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode:
            raise ValueError(result.stderr.strip() or result.stdout.strip())
        return json.loads(result.stdout)

    existing = {machine["name"]: machine for machine in run_core("ls")["machines"]}
    # Validate names before adding anything. Never remove/re-add a conflicting
    # connection: its name may be used by open app spaces and terminals.
    for name, target in machines.items():
        if name in existing:
            machine = existing[name]
            if (
                machine["target"] != target
                or machine["session"] is not None
                or machine["via"]
                or machine["temporary"]
            ):
                raise ValueError(
                    f"machine {name!r} conflicts with declared SSH target {target!r}; "
                    "resolve it with hc machine commands before retrying"
                )
    for name, target in machines.items():
        if name not in existing:
            run_core("add", "--name", name, "--", target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core", required=True)
    parser.add_argument("--machines", required=True, type=Path)
    args = parser.parse_args()
    try:
        reconcile_native_machines(args.core, json.loads(args.machines.read_text()))
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        parser.exit(1, f"herdr-native-machines: {error}\n")


if __name__ == "__main__":
    main()
