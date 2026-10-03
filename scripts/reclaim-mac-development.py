#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# ///
"""Explicit, preview-first cleanup of Xcode/Mole caches or a verified FG offload."""

import argparse
import fnmatch
from pathlib import Path
import platform
import shutil
import subprocess


def require_local_directory(path: Path) -> None:
    """Reject symlinks, including symlinked parents, before recursive removal."""
    if path.resolve() != path or not path.is_dir():
        raise ValueError(f"Cleanup requires a real directory: {path}")


def xcode_cleanup_targets(home: Path, versions: list[str]) -> list[Path]:
    """Only DerivedData and explicitly named DeviceSupport versions are eligible."""
    xcode = home / "Library/Developer/Xcode"
    targets = [xcode / "DerivedData"]
    for version in versions:
        if not version or version in (".", "..") or "/" in version:
            raise ValueError("DeviceSupport must be a single directory name")
        targets.append(xcode / "iOS DeviceSupport" / version)
    for path in targets:
        require_local_directory(path)
    return targets


def verify_fg_copy(source: Path, destination: str) -> None:
    """Require an exact checksum mirror on NUC, including Git and ignored files."""
    require_local_directory(source)
    # Limit deletion authority to the reviewed offload destination, not arbitrary hosts.
    if destination != "nuc:/home/emiller/src/fg-mactraitor-20261003/":
        raise ValueError("FG cleanup requires the reviewed NUC migration directory")
    subprocess.run(
        ["ssh", "-o", "BatchMode=yes", "nuc", 'test "$(hostname)" = nuc'],
        check=True,
    )
    result = subprocess.run(
        [
            "rsync",
            "-aHnc",
            "--delete",
            "--itemize-changes",
            "-e",
            "ssh -o BatchMode=yes",
            f"{source}/",
            destination,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    # Linux cannot reproduce macOS symlink mode bits. Still require identical
    # link targets, file contents, regular-file permissions, and directory entries.
    differences = []
    for line in result.stdout.splitlines():
        flags = line.split(" ", 1)[0]
        if flags.startswith(".L") and flags[2:].replace(".", "") == "p":
            continue
        differences.append(line)
    if differences or result.stderr.strip():
        raise ValueError(
            "FG mirror is not exact; refusing removal:\n"
            + "\n".join(differences)
            + result.stderr
        )


def reviewed_cleanup_targets(
    home: Path, action: str, manifest: Path | None
) -> list[Path]:
    """Select disposable caches or ignored artifacts, preserving protected/open paths."""
    if action == "caches":
        candidates = [
            home / name
            for name in (
                ".bun/install/cache",
                ".npm/_cacache",
                ".npm/_npx",
                ".cache/uv",
                "Library/pnpm/store",
                "Library/Caches/pnpm",
                "Library/Caches/CocoaPods",
                "Library/Caches/rattler",
                "Library/Caches/@granolaelectron-updater",
                "Library/Caches/@lineardesktop-updater",
                "Library/Caches/notion-updater",
                "Library/Caches/go-build",
                "Library/Caches/electron",
                "Library/Caches/ReactNative",
                "Library/Caches/node-gyp",
                "Library/Caches/net.imput.helium",
            )
        ]
    else:
        if manifest is None:
            raise ValueError(
                "Artifact cleanup requires an explicitly reviewed --manifest"
            )
        candidates = [Path(line) for line in manifest.read_text().splitlines() if line]
    whitelist = (home / ".config/mole/whitelist").read_text().splitlines()
    patterns = [
        line.replace("~", str(home), 1)
        for line in whitelist
        if line and not line.startswith("#")
    ]
    opened = subprocess.run(
        ["lsof", "-nP", "-a", "-u", str(home.owner()), "-F", "n"],
        capture_output=True,
        text=True,
        check=True,
    )
    open_paths = [
        Path(line[1:]) for line in opened.stdout.splitlines() if line.startswith("n/")
    ]
    targets = []
    for path in candidates:
        if not path.exists():
            continue
        require_local_directory(path)
        if not path.is_relative_to(home) or path == home:
            raise ValueError(f"Cleanup outside home refused: {path}")
        protected = any(
            fnmatch.fnmatch(str(parent), pattern)
            for parent in (path, *path.parents)
            for pattern in patterns
        ) or any(pattern.startswith(f"{path}/") for pattern in patterns)
        in_use = any(
            p.is_relative_to(path) or (action == "artifacts" and p == path.parent)
            for p in open_paths
        )
        if protected or in_use:
            print(f"Skipping protected or open path: {path}", flush=True)
            continue
        if action == "artifacts":
            if path.name not in {
                "node_modules",
                ".next",
                "DerivedData",
                "Pods",
                "__pycache__",
                ".pytest_cache",
                ".ruff_cache",
            }:
                print(f"Skipping non-cache artifact: {path}", flush=True)
                continue
            ignored = subprocess.run(
                ["git", "-C", str(path.parent), "check-ignore", "-q", str(path)],
                capture_output=True,
            )
            if ignored.returncode != 0:
                print(
                    f"Skipping non-ignored or unverifiable artifact: {path}", flush=True
                )
                continue
            tracked = subprocess.run(
                ["git", "-C", str(path.parent), "ls-files", "--", str(path)],
                capture_output=True,
                check=True,
            )
            if tracked.stdout:
                print(f"Skipping tracked artifact: {path}", flush=True)
                continue
        targets.append(path)
    return targets


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action", choices=["xcode", "fg", "mole-cache", "caches", "artifacts"]
    )
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--device-support", action="append", default=[])
    parser.add_argument("--verified-copy")
    args = parser.parse_args()
    if platform.system() != "Darwin":
        parser.error("This command is only for the Mac")
    home = Path.home()
    if args.action in ("caches", "artifacts"):
        targets = reviewed_cleanup_targets(home, args.action, args.manifest)
    elif args.action == "xcode":
        targets = xcode_cleanup_targets(home, args.device_support)
        running = subprocess.run(
            ["pgrep", "-x", "Xcode|xcodebuild|SWBBuildService|swift-frontend"],
            capture_output=True,
            text=True,
        )
        if running.returncode != 1:
            parser.error("Quit Xcode and wait for builds to exit before cleanup")
    elif args.action == "mole-cache":
        targets = [home / ".cache/mole"]
        require_local_directory(targets[0])
        running = subprocess.run(
            ["pgrep", "-f", "mole-disk-report|disk-reclaim-report|/bin/(mole|mo)( |$)"],
            capture_output=True,
            text=True,
        )
        if running.returncode != 1:
            parser.error("Wait for Mole and disk reports to exit before cleanup")
    else:
        if not args.verified_copy:
            parser.error("FG removal requires --verified-copy")
        targets = [home / "src/fg"]
        verify_fg_copy(targets[0], args.verified_copy)
        # Renaming stops new clients from opening the old path during final verification.
        if args.apply:
            retired = home / "src/fg.offload-verified"
            if retired.exists() or retired.is_symlink():
                parser.error(f"Refusing to overwrite {retired}")
            targets[0].rename(retired)
            try:
                verify_fg_copy(retired, args.verified_copy)
            except BaseException:
                retired.rename(targets[0])
                raise
            targets = [retired]
    for path in targets:
        print(f"{'Removing' if args.apply else 'Would remove'}: {path}", flush=True)
        if args.apply:
            require_local_directory(path)
            shutil.rmtree(path)
    if not args.apply:
        print("Preview only. Use --apply after explicit cleanup approval.")


if __name__ == "__main__":
    main()
