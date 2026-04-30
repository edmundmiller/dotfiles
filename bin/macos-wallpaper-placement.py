#!/usr/bin/env python3

import os
import plistlib
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(
            f"usage: {Path(sys.argv[0]).name} <index.plist> [placement]",
            file=sys.stderr,
        )
        return 2

    plist_path = Path(os.path.expanduser(sys.argv[1]))
    placement = sys.argv[2] if len(sys.argv) == 3 else "Centered"

    with plist_path.open("rb") as f:
        data = plistlib.load(f)

    def mutate(obj: object) -> None:
        if isinstance(obj, dict):
            encoded = obj.get("EncodedOptionValues")
            if isinstance(encoded, (bytes, bytearray)):
                try:
                    decoded = plistlib.loads(encoded)
                except Exception:
                    decoded = None
                if isinstance(decoded, dict):
                    picker = (
                        decoded.setdefault("values", {})
                        .setdefault("placement", {})
                        .setdefault("picker", {})
                        .setdefault("_0", {})
                    )
                    picker["id"] = placement
                    obj["EncodedOptionValues"] = plistlib.dumps(
                        decoded, fmt=plistlib.FMT_BINARY
                    )
            for value in obj.values():
                mutate(value)
        elif isinstance(obj, list):
            for value in obj:
                mutate(value)

    mutate(data)

    with plist_path.open("wb") as f:
        plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
