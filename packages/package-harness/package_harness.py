#!/usr/bin/env python3
"""Read-only package maintainer harness."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

METADATA = "package-harness.json"
REQUIRED_KEYS = {"source", "ref", "patches", "checks"}


class HarnessError(Exception):
    pass


@dataclass(frozen=True)
class Unit:
    group: str
    name: str
    path: Path

    @property
    def metadata_path(self) -> Path:
        return self.path / METADATA if self.path.is_dir() else self.path.with_suffix(f"{self.path.suffix}.{METADATA}")


def repo_root(start: Path | None = None) -> Path:
    current = (start or Path.cwd()).resolve()
    for candidate in (current, *current.parents):
        if (candidate / "flake.nix").is_file() and (candidate / "packages").is_dir() and (candidate / "overlays").is_dir():
            return candidate
    raise HarnessError("repository root not found (expected flake.nix, packages/, and overlays/)")


def discover(root: Path) -> list[Unit]:
    units: list[Unit] = []
    for group in ("overlays", "packages"):
        base = root / group
        for path in sorted(base.iterdir(), key=lambda item: item.name):
            if path.name.startswith(".") or path.name == "AGENTS.md":
                continue
            if path.is_dir():
                units.append(Unit(group, path.name, path))
            elif path.suffix == ".nix":
                units.append(Unit(group, path.stem, path))
    return units


def resolve_unit(root: Path, name: str) -> Unit:
    matches = [unit for unit in discover(root) if unit.name == name]
    if not matches:
        raise HarnessError(f"unit {name!r} not found")
    if len(matches) > 1:
        locations = ", ".join(f"{unit.group}/{unit.path.name}" for unit in matches)
        raise HarnessError(f"unit {name!r} is ambiguous: {locations}")
    unit = matches[0]
    if not unit.metadata_path.is_file():
        raise HarnessError(f"unit {name!r} is undeclared (missing {METADATA})")
    return unit


def load_metadata(unit: Unit) -> dict[str, object]:
    try:
        data = json.loads(unit.metadata_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise HarnessError(f"invalid metadata {unit.metadata_path}: {error}") from error
    if not isinstance(data, dict) or set(data) != REQUIRED_KEYS:
        raise HarnessError(f"invalid metadata {unit.metadata_path}: expected exactly {sorted(REQUIRED_KEYS)}")
    if not all(isinstance(data[key], str) and data[key] for key in ("source", "ref")):
        raise HarnessError(f"invalid metadata {unit.metadata_path}: source and ref must be non-empty strings")
    if not isinstance(data["patches"], list) or not all(isinstance(item, str) and item for item in data["patches"]):
        raise HarnessError(f"invalid metadata {unit.metadata_path}: patches must be a list of paths")
    checks = data["checks"]
    if not isinstance(checks, list) or not checks or not all(
        isinstance(command, list) and command and all(isinstance(arg, str) and arg for arg in command)
        for command in checks
    ):
        raise HarnessError(f"invalid metadata {unit.metadata_path}: checks must be a non-empty list of argument lists")
    return data


def commands_for(unit: Unit, checkout: Path, metadata: dict[str, object]) -> list[list[str]]:
    source = str(metadata["source"])
    ref = str(metadata["ref"])
    patches = [str(item) for item in metadata["patches"]]
    checks = [[str(arg) for arg in command] for command in metadata["checks"]]
    patch_root = unit.path if unit.path.is_dir() else unit.path.parent
    return [
        ["git", "clone", "--no-checkout", source, str(checkout)],
        ["git", "-C", str(checkout), "checkout", "--detach", ref],
        *[["git", "-C", str(checkout), "apply", str((patch_root / patch).resolve())] for patch in patches],
        *checks,
    ]


def check(unit: Unit) -> None:
    metadata = load_metadata(unit)
    with tempfile.TemporaryDirectory(prefix=f"pkg-check-{unit.name}-") as temporary:
        checkout = Path(temporary) / "upstream"
        commands = commands_for(unit, checkout, metadata)
        for index, command in enumerate(commands):
            cwd = checkout if index >= 2 + len(metadata["patches"]) else None
            print("+", " ".join(command), flush=True)
            subprocess.run(command, cwd=cwd, check=True)


def list_units(root: Path) -> None:
    for unit in discover(root):
        state = "declared" if unit.metadata_path.is_file() else "undeclared"
        print(f"{unit.group}/{unit.path.name}\t{state}")


def main(argv: Sequence[str] | None = None) -> int:
    args = list(argv if argv is not None else sys.argv[1:])
    try:
        if not args:
            raise HarnessError("usage: pkg-list | pkg-check <unit>")
        root = repo_root()
        if args[0] == "pkg-list" and len(args) == 1:
            list_units(root)
        elif args[0] == "pkg-check" and len(args) == 2:
            check(resolve_unit(root, args[1]))
        elif args[0] == "pkg-check":
            raise HarnessError("usage: pkg-check <unit>")
        else:
            raise HarnessError("usage: pkg-list | pkg-check <unit>")
        return 0
    except HarnessError as error:
        print(f"{args[0] if args else 'package-harness'}: {error}", file=sys.stderr)
        return 2
    except subprocess.CalledProcessError as error:
        print(f"pkg-check: command failed with exit {error.returncode}: {' '.join(error.cmd)}", file=sys.stderr)
        return error.returncode or 1


if __name__ == "__main__":
    raise SystemExit(main())
