#!/usr/bin/env python3

import os
import plistlib
import sys
from pathlib import Path

SEQERA_PURPLE = "201637"


def parse_color(hex_color: str) -> list[float]:
    value = hex_color.strip().removeprefix("#")
    if len(value) != 6 or any(ch not in "0123456789abcdefABCDEF" for ch in value):
        raise ValueError(f"invalid hex color: {hex_color}")
    return [int(value[i : i + 2], 16) / 255.0 for i in range(0, 6, 2)] + [1.0]


def main() -> int:
    if len(sys.argv) not in (2, 3, 4):
        print(
            f"usage: {Path(sys.argv[0]).name} <index.plist> [placement] [hex-color]",
            file=sys.stderr,
        )
        return 2

    plist_path = Path(os.path.expanduser(sys.argv[1]))
    placement = sys.argv[2] if len(sys.argv) >= 3 else "Centered"
    color = parse_color(sys.argv[3]) if len(sys.argv) >= 4 else parse_color(SEQERA_PURPLE)

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
                    values = decoded.setdefault("values", {})
                    picker = (
                        values.setdefault("placement", {})
                        .setdefault("picker", {})
                        .setdefault("_0", {})
                    )
                    picker["id"] = placement

                    color_node = (
                        values.setdefault("color", {})
                        .setdefault("color", {})
                        .setdefault("_0", {})
                        .setdefault("color", {})
                    )
                    color_node["components"] = color

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
