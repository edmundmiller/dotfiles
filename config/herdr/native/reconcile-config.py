#!/usr/bin/env python3
"""Reconcile native Herdr preferences without touching app-owned runtime state.

Nix invokes this stdlib-only activation helper with its Python interpreter.
Invalid JSON or non-object values fail before any file is written. Unmanaged
keys survive; managed keys follow the repository on every activation.
"""

import argparse
import json
import os
from pathlib import Path
import tempfile


def read_config_object(path):
    """Read one settings object, rejecting damaged input instead of resetting it."""
    if not path.exists():
        return {}
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"herdr-native-config: expected JSON object at {path}")
    return value


def merge_managed_config(existing, managed):
    """Overlay managed leaves, preserving unrelated settings at every depth."""
    merged = dict(existing)
    for key, value in managed.items():
        if isinstance(value, dict):
            old = existing.get(key, {})
            if not isinstance(old, dict):
                raise ValueError(f"herdr-native-config: expected object for {key}")
            merged[key] = merge_managed_config(old, value)
        else:
            merged[key] = value
    return merged


def reconcile_native_config(home, source, core):
    """Validate all preferences first, then replace changed files atomically."""
    pending = []
    for name in ("settings.json", "keys.json", "programs.json"):
        target = home / name
        template = source / name
        if not template.is_file():
            raise ValueError(f"herdr-native-config: missing template {template}")
        managed = read_config_object(template)
        if name == "settings.json":
            managed["core"] = core
        before = target.read_bytes() if target.exists() else None
        merged = merge_managed_config(read_config_object(target), managed)
        after = (json.dumps(merged, indent=2, ensure_ascii=False) + "\n").encode()
        if before != after or target.is_symlink():
            pending.append((target, before, after))
    home.mkdir(parents=True, exist_ok=True)
    for target, before, after in pending:
        # The app may save preferences while activation is running. Refuse a
        # changed snapshot rather than knowingly overwrite its newer choices.
        current = target.read_bytes() if target.exists() else None
        if current != before:
            raise ValueError(
                f"herdr-native-config: {target} changed during activation; retry"
            )
        descriptor, temporary = tempfile.mkstemp(prefix=f".{target.name}.", dir=home)
        try:
            with os.fdopen(descriptor, "wb") as output:
                output.write(after)
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary, target)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--core", required=True)
    args = parser.parse_args()
    try:
        reconcile_native_config(args.home, args.source, args.core)
    except (OSError, ValueError) as error:
        parser.exit(1, f"herdr-native-config: {error}\n")


if __name__ == "__main__":
    main()
