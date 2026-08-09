from __future__ import annotations

import shutil
from pathlib import Path


def command_path(name: str, *fallbacks: Path) -> str | None:
    found = shutil.which(name)
    if found:
        return found
    for fallback in fallbacks:
        if fallback.is_file():
            return str(fallback)
    return None


def nix_path() -> str | None:
    return command_path(
        "nix",
        Path("/run/current-system/sw/bin/nix"),
        Path("/nix/var/nix/profiles/default/bin/nix"),
    )


def bun_path() -> str | None:
    return command_path("bun", Path.home() / ".bun" / "bin" / "bun")
