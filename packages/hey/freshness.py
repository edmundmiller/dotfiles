"""Best-effort source and active-system warnings. Never change checkout contents."""

from contextlib import suppress
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import sys
import time

INTERVAL = 15 * 60
CURRENT_SYSTEM = Path("/run/current-system")


def run(args):
    # Let Git clean up locks, then force-stop any remaining credential/SSH group.
    with subprocess.Popen(
        args,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        env=os.environ | {
            "GIT_TERMINAL_PROMPT": "0",
            "GCM_INTERACTIVE": "never",
            "GIT_ASKPASS": "",
            "SSH_ASKPASS_REQUIRE": "never",
            "GIT_OPTIONAL_LOCKS": "0",
        },
        start_new_session=True,
    ) as child:
        try:
            output, _ = child.communicate(timeout=1)
        except BaseException:
            # Cancellation must finish cleanup, even if another signal arrives.
            blocked = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGINT, signal.SIGTERM})
            try:
                with suppress(ProcessLookupError):
                    os.killpg(child.pid, signal.SIGTERM)
                deadline = time.monotonic() + 0.2
                try:
                    child.communicate(timeout=0.2)
                except subprocess.TimeoutExpired:
                    pass
                # Git can exit before its transport finishes handling SIGTERM.
                time.sleep(max(0, deadline - time.monotonic()))
                with suppress(ProcessLookupError):
                    os.killpg(child.pid, signal.SIGKILL)
                child.communicate()
            finally:
                signal.pthread_sigmask(signal.SIG_SETMASK, blocked)
            raise
        if child.returncode:
            raise ValueError("command failed")
        return os.fsdecode(output).strip()


def git(root, *args):
    return run(["git", "-C", str(root), *args])


def warn(message):
    print(f"hey: {message}", file=sys.stderr)


def check_source(root, knowledge):
    try:
        ahead, behind = map(int, git(root, "rev-list", "--left-right", "--count", "HEAD...origin/main").split())
    except ValueError:
        warn("cannot compare with origin/main; run git fetch origin main when online")
        return
    if not behind:
        return
    try:
        git(root, "merge-base", "HEAD", "origin/main")
    except ValueError:
        warn(f"checkout {root} has no known common ancestor with {knowledge}; inspect shallow history before updating")
        return
    branch = git(root, "rev-parse", "--abbrev-ref", "HEAD")
    dirty = bool(git(root, "status", "--porcelain", "--untracked-files=normal"))
    details = ["detached HEAD" if branch == "HEAD" else f"branch {branch}"]
    if dirty:
        details.append("dirty checkout")
    if ahead:
        details.append(f"{ahead} commit(s) ahead of origin/main")
    warn(f"checkout {root} is {behind} commit(s) behind {knowledge} ({', '.join(details)})")
    if branch == "main" and not dirty and not ahead:
        command = f"git -C {shlex.quote(str(root))}"
        warn(f"to update explicitly: {command} fetch origin && {command} merge --ff-only origin/main")
    else:
        warn("checkout left untouched; reconcile this work with main before updating")


def check():
    if os.environ.get("HEY_FRESHNESS") == "0":
        return
    root = Path(git(Path.cwd(), "rev-parse", "--show-toplevel"))
    if not (root / "packages/hey/default.nix").is_file():
        return
    if not (root / "flake.nix").is_file():
        return
    common = Path(git(root, "rev-parse", "--git-common-dir"))
    if not common.is_absolute():
        common = root / common
    # Shared worktrees share the fetch budget. The lock never waits for a peer.
    knowledge = "cached origin/main; refresh unavailable"
    try:
        with (common / "hey-freshness").open("a+") as cache:
            fcntl.flock(cache, fcntl.LOCK_EX | fcntl.LOCK_NB)
            cache.seek(0)
            try:
                state = json.load(cache)
            except (ValueError, TypeError):
                state = {}
            if not isinstance(state, dict):
                state = {}
            now = time.time()
            if now - state.get("attempt", 0) >= INTERVAL:
                state = {"attempt": now, "fresh": False}
                try:
                    git(
                        root,
                        "-c", "maintenance.auto=false",
                        "-c", "gc.auto=0",
                        "-c", f"core.hooksPath={os.devnull}",
                        "fetch", "--no-tags", "--no-write-fetch-head", "origin",
                        "+refs/heads/main:refs/remotes/origin/main",
                    )
                    state["fresh"] = True
                except (ValueError, OSError, subprocess.TimeoutExpired):
                    pass
                cache.seek(0)
                cache.truncate()
                json.dump(state, cache)
            knowledge = "origin/main" if state.get("fresh") else "cached origin/main; refresh failed/offline"
    except (OSError, ValueError, TypeError):
        pass  # A busy or unwritable cache only disables refresh, not comparison.

    try:
        check_source(root, knowledge)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        pass  # Source inspection cannot suppress the independent active check.

    # A built result link is not activation evidence. Read the active system.
    try:
        revision = json.loads((CURRENT_SYSTEM / "darwin-version.json").read_text()).get("configurationRevision")
    except (OSError, ValueError):
        revision = run([str(CURRENT_SYSTEM / "sw/bin/nixos-version"), "--configuration-revision"])
        provenance = re.fullmatch(r"dotfiles=([0-9a-f]{40});agents-workspace=[0-9a-f]{40}(?:-dirty)?", revision)
        if provenance:
            revision = provenance[1]
    if not isinstance(revision, str) or len(revision) != 40 or any(c not in "0123456789abcdef" for c in revision):
        return
    try:
        git(root, "merge-base", "--is-ancestor", revision, "HEAD")
        count = int(git(root, "rev-list", "--count", f"{revision}..HEAD"))
    except ValueError:
        return
    if count:
        warn(f"active system {revision[:12]} is {count} commit(s) behind this checkout; source updates do not activate it")


if __name__ == "__main__":
    def cancel(signum, _frame):
        raise SystemExit(128 + signum)

    for signum in (signal.SIGINT, signal.SIGTERM):
        if signal.getsignal(signum) != signal.SIG_IGN:
            signal.signal(signum, cancel)
    try:
        check()
    except (OSError, ValueError, TypeError, subprocess.TimeoutExpired):
        # An advisory must never prevent the requested task from running.
        pass
