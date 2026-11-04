#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# [tool.uv]
# exclude-newer = "2026-11-04T00:00:00Z"
# ///
"""Read-only ESP capacity check for UNAS's systemd-boot Type #1 entries."""

import json
import os
from pathlib import Path
import re
import sys


def check_esp_capacity(root, system, previous):
    # Resolve absolute store symlinks against the installation, never the rescue store.
    os.chroot(root)
    os.chdir("/")
    settings = json.loads((Path(system) / "etc/unas-recovery-boot.json").read_text())
    if settings["esp"] != "/boot" or settings["xbootldr"] is not None:
        raise ValueError("unsupported boot mount layout")
    limit = settings["configurationLimit"] or 0
    if type(limit) is not int or limit < 0:
        raise ValueError("invalid systemd-boot configuration limit")

    systems = [Path(system), Path(previous)]
    profiles = Path("/nix/var/nix/profiles")
    for directory, pattern in (
        (profiles, "system-*-link"),
        (profiles / "system-profiles", "*-link"),
    ):
        generations = {}
        for link in directory.glob(pattern):
            match = re.fullmatch(r"(.+)-(\d+)-link", link.name)
            if match:
                generations.setdefault(match[1], []).append((int(match[2]), link))
        for versions in generations.values():
            selected = sorted(versions)[-limit:] if limit else sorted(versions)
            systems.extend(link.resolve(strict=True) for _, link in selected)

    filesystem = os.statvfs("/boot")
    block = max(filesystem.f_frsize, filesystem.f_bsize)

    def allocated(size):
        return ((size + block - 1) // block) * block

    payloads = {}
    entries = 0

    def read_bootspec(bootspec):
        nonlocal entries
        spec = bootspec["org.nixos.bootspec.v1"]
        if spec.get("initrdSecrets") is not None:
            raise ValueError("initrd secret appenders have unbounded output; inspect manually")
        if bootspec.get("org.nixos.extra-initrd.v1", {}).get("paths"):
            raise ValueError("extra initrds require manual capacity inspection")
        sources = [spec["kernel"], spec["initrd"]]
        devicetree = bootspec.get("org.nixos.systemd-boot", {}).get("devicetree")
        if devicetree:
            sources.append(devicetree)
        for source in sources:
            source = Path(source).resolve(strict=True)
            store_subdir = source.relative_to("/nix/store").parts[0]
            # Match systemd-boot-builder.py's boot_path, including store-file inputs.
            name = source.name if source.name == store_subdir else f"{store_subdir}-{source.name}"
            payloads[Path("/boot/EFI/nixos") / f"{name}.efi"] = source
        # Includes labels, parameters and paths, plus profile names and entry syntax.
        entries += allocated(len(json.dumps(bootspec).encode()) + 4096)
        for child in bootspec.get("org.nixos.specialisation.v1", {}).values():
            read_bootspec(child)

    for candidate in systems:
        read_bootspec(json.loads((candidate / "boot.json").read_text()))

    copies = []
    for destination, source in payloads.items():
        size = allocated(source.stat().st_size)
        if not destination.is_file():
            copies.append(size)
    # bootctl can replace both vendor and fallback EFI binaries. Extra files can
    # also replace existing files, so charge their whole size without cleanup credit.
    efi_size = allocated(Path(settings["efiBinary"]).stat().st_size)
    copies.extend([efi_size, efi_size])
    copies.extend(allocated(Path(source).stat().st_size) for source in settings["extraFiles"].values())
    entries += sum(allocated(len(text.encode())) for text in settings["extraEntries"].values())
    # Reserve one additional largest copy for temporary replacement, and 16 MiB
    # for directories, loader metadata, allocation slack and bootctl state.
    required = sum(copies) + max(copies, default=0) + entries + 16 * 1024 * 1024
    available = filesystem.f_bavail * filesystem.f_frsize
    if required > available:
        raise ValueError(
            f"needs {required} free bytes, has {available}; "
            "retain rollback profiles and request explicit retirement approval, then recheck"
        )
    print(f"ESP preflight passed: requires {required} free bytes, has {available}")


if __name__ == "__main__":
    try:
        if len(sys.argv) != 4:
            raise ValueError("usage: unas-recovery-preflight.py <root> <system> <previous>")
        check_esp_capacity(*sys.argv[1:])
    except (OSError, ValueError, KeyError, TypeError) as error:
        sys.exit(f"UNAS recovery refused: ESP preflight: {error}")
