#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# ///
"""Shared, source-read-only validation for hey, CI, and package publication."""

import argparse
import fnmatch
import hashlib
import json
import os
import platform
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# These are portable check derivations, not host evaluations or VM builds.
# Hook-owned tests are deliberately not repeated here.
CHECKS = {
    "validation-tests": [
        "scripts/validation.py",
        "bin/hey*",
        "bin/hey.d/*",
        "bin/qa-changed",
        "tests/test_validation.py",
        ".github/workflows/*",
        ".codex/hooks.json",
        ".omp/hooks/*",
    ],
    "zunit-tests": ["config/tmux/*", "config/zsh/*", "packages/zunit/*"],
    "package-harness-tests": [
        "packages/package-harness/*",
        "packages/*/default.nix",
        "packages/*/patches/*",
    ],
    "package-policy-tests": [
        "packages/*",
        "bin/check-package-layout",
        "bin/check-patch-locality",
        "tests/test_package_policy.py",
    ],
    "agent-run-tests": [
        "bin/agent-*",
        "bin/hey.d/agent-run.nu",
        "tests/test_agent_run.py",
        "tests/test_skill_quality_validator.py",
        "skills/catalog/skill-quality/*",
    ],
    "agent-docs-contract": [
        "AGENT_WORKFLOW.md",
        "docs/README.md",
        "docs/agent-guardrails.md",
        "docs/validation.md",
    ],
    "omp-thin-harness-tests": [
        "bin/bootstrap",
        "config/agents/core.md",
        "config/codex/config.toml",
        "config/opencode/opencode.jsonc",
        "config/omp/*",
        "modules/agents/claude/*",
        "modules/agents/codex/*",
        "modules/agents/omp/*",
        "modules/agents/opencode/*",
        "modules/agents/pi/*",
        "modules/agents/plannotator/*",
        "tests/test_agent_instruction_wiring.py",
        "tests/test_agent_response_contract.py",
        "tests/test_codex_model_config.py",
        "tests/test_omp_ttsr_rules.py",
        "tests/omp_lazy_extensions.test.js",
        "tests/fixtures/omp-ttsr-rules.json",
    ],
    "omp-config": ["config/omp/config.yml", "modules/agents/omp/*"],
    "agent-skills-marker-migration-tests": [
        "modules/agents/skills/*",
        "tests/test_agent_skills_marker_migration.py",
    ],
    "ast-grep-tests": ["ast-grep/*", "sgconfig.yml"],
    "displayctl-tests": ["packages/displayctl/*"],
    "trmnl-agent-message-structure": ["config/trmnl/agent-message/*"],
    "nix-private-github": [
        "bin/nix-private-github",
        "bin/tests/*nix_private*",
        "bin/tests/nix-private*",
    ],
    "hey-nuc-deploy-mode": ["bin/hey.d/remote.nu", "bin/tests/hey-nuc-deploy-mode.nu"],
    "hermes-cron-executor-source-tests": [
        "tests/test_hermes_cron_executors.py",
        "hosts/nuc/*",
        "modules/agents/hermes/*",
    ],
    "herdr-config-check": [
        "modules/shell/herdr/*",
        "config/herdr/*",
        "packages/herdr/*",
    ],
    "screentime-backup-cli-tests": ["packages/screentime-backup/*"],
    "discrawl-backup-cli-tests": ["packages/discrawl-backup/*"],
    "hermes-buzz-patch-stack": ["modules/agents/hermes/*"],
    "hermes-buzz-final-stack-behavior": ["modules/agents/hermes/*"],
    "hermes-cron-single-owner": ["modules/agents/hermes/*"],
    "hermes-dashboard-profile-liveness": ["modules/agents/hermes/*"],
    "nuc-deployment-provenance": [
        "hosts/nuc/_tests/deployment-provenance.nix",
        "bin/hey.d/remote.nu",
    ],
    "nuc-hermes-displayctl-wiring": ["hosts/nuc/*", "packages/displayctl/*"],
    "nuc-hermes-cron-failure-summary": ["tests/test_hermes_cron_failure_summary.py"],
}

DARWIN_CHECKS = [
    "apple-container-pilot-assertions",
    "audio-priority-bar-regressions",
    "screentime-backup-darwin-assertions",
    "discrawl-backup-darwin-assertions",
    "darwin-tailscaled-owner-assertions",
    "hermes-local-libffi-regression",
    "hermes-local-tokenizers-cc-regression",
    "dji-mic-mini-receiver-mute-regressions",
    "dji-mic-mini-platform-boundaries",
]

PLATFORM_PATHS = {
    "darwin": [
        "hosts/mactraitorpro/*",
        "hosts/seqeratop/*",
        "modules/*",
        "packages/*",
        "config/*",
    ],
    "herdr-vm": [
        "modules/shell/herdr/*",
        "modules/desktop/term/tmux/*",
        "config/tmux/*",
        "config/herdr/*",
        "packages/herdr/*",
        "modules/options.nix",
    ],
    "services-vm": ["modules/services/*"],
    "nixos": ["hosts/nuc/*", "modules/*", "packages/*", "config/*"],
}


def git(root, *args, check=True):
    return subprocess.run(
        ["git", "-C", str(root), *args], check=check, capture_output=True
    )


def names(result):
    return [os.fsdecode(name) for name in result.stdout.split(b"\0") if name]


def source_files(root):
    result = git(root, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
    return sorted(set(names(result)))


def fingerprint(root):
    digest = hashlib.sha256()
    for name in source_files(root):
        path = root / name
        digest.update(os.fsencode(name) + b"\0")
        if path.is_symlink():
            digest.update(b"link" + os.fsencode(os.readlink(path)))
        elif path.is_file():
            digest.update(str(path.stat().st_mode).encode() + path.read_bytes())
        else:
            digest.update(b"missing")
    return digest.digest()


def selected_files(root, base=None, head="HEAD", full=False, scopes=()):
    if full:
        files = source_files(root)
    else:
        if base is None:
            base = (
                "origin/main"
                if git(
                    root, "rev-parse", "--verify", "origin/main", check=False
                ).returncode
                == 0
                else "HEAD"
            )
        files = names(
            git(root, "diff", "--name-only", "--no-renames", "-z", f"{base}...{head}")
        )
        files += names(git(root, "diff", "--name-only", "--no-renames", "-z", "HEAD"))
        files += names(git(root, "ls-files", "--others", "--exclude-standard", "-z"))
    normalized = []
    for scope in scopes:
        path = Path(os.path.normpath(scope))
        if path.is_absolute() or ".." in path.parts:
            raise ValueError("Scopes must be repository-relative paths without '..'.")
        normalized.append(path.as_posix())
    return sorted(
        {
            f
            for f in files
            if not normalized
            or any(s == "." or f == s or f.startswith(s + "/") for s in normalized)
        }
    )


def matches(files, patterns):
    return any(fnmatch.fnmatchcase(f, p) for f in files for p in patterns)


def package_plan(root, files, full=False, packages=()):
    if not (
        full or packages or matches(files, ["packages/pi-packages/*", "bin/qa-changed"])
    ):
        return [], False
    workspace = root / "packages/pi-packages"
    available = {
        p.parent.name: json.loads(p.read_text())
        for pattern in ("pi-*/package.json", "omp-*/package.json")
        for p in workspace.glob(pattern)
    }
    shared = full or matches(
        files,
        [
            "packages/pi-packages/package.json",
            "packages/pi-packages/bun.lock",
            "packages/pi-packages/tsconfig*",
            "packages/pi-packages/tests/*",
            "bin/qa-changed",
        ],
    )
    selected = set(packages)
    if selected - available.keys():
        raise ValueError(
            "Unknown packages: " + ", ".join(sorted(selected - available.keys()))
        )
    changed_packages = {
        f.split("/")[2]
        for f in files
        if f.startswith("packages/pi-packages/") and len(f.split("/")) > 3
    }
    # A removed manifest no longer exposes its dependency name. Check survivors
    # rather than silently omitting consumers of the removed package.
    shared = shared or any(
        f"packages/pi-packages/{name}/package.json" in files
        for name in changed_packages - available.keys()
    )
    selected.update(available if shared else changed_packages & available.keys())
    # A workspace dependency change also checks its transitive consumers.
    while True:
        consumers = {
            name
            for name, data in available.items()
            if any(
                available[p]["name"] in data.get(kind, {})
                for p in selected
                for kind in (
                    "dependencies",
                    "devDependencies",
                    "peerDependencies",
                    "optionalDependencies",
                )
            )
        }
        if consumers <= selected:
            break
        selected.update(consumers)
    return sorted(selected), bool(selected or shared)


def plan(root, args):
    files = selected_files(root, args.base_ref, args.head_ref, args.full, args.paths)
    packages, integration = package_plan(root, files, args.full, args.package)
    checks = [
        name
        for name, patterns in CHECKS.items()
        if args.full
        or matches(files, patterns + ["flake.nix", "flake.lock", "lib/*", "overlays/*"])
    ]
    if args.packages_only:
        checks = []
    if args.platform:
        # Explicit platform runs are independent of the portable suite.
        target = args.platform
        if (
            args.ci
            and not args.full
            and not matches(
                files,
                PLATFORM_PATHS[target]
                + [
                    "flake.nix",
                    "flake.lock",
                    "lib/*",
                    "overlays/*",
                    "scripts/validation.py",
                    ".github/workflows/ci.yml",
                ],
            )
        ):
            target = None
        return {
            "files": files,
            "hooks": False,
            "checks": [],
            "packages": [],
            "integration": False,
            "platform": target,
        }
    return {
        "files": files,
        "hooks": bool(files) and not args.packages_only,
        "checks": checks,
        "packages": packages,
        "integration": integration,
        "platform": None,
    }


def snapshot(root, target):
    """Copy source, never the user's Git directory, ignored state, or dependencies."""
    for name in source_files(root):
        src, dst = root / name, target / name
        if not src.exists() and not src.is_symlink():
            continue
        if src.is_dir() and not src.is_symlink():
            raise ValueError(f"Submodule/directory cannot be snapshotted: {name}")
        dst.parent.mkdir(parents=True, exist_ok=True)
        if src.is_symlink():
            link = os.readlink(src)
            if Path(link).is_absolute() or not (
                dst.parent / link
            ).resolve().is_relative_to(target.resolve()):
                raise ValueError(f"External symlink cannot be validated safely: {name}")
            dst.symlink_to(link)
        else:
            shutil.copy2(src, dst)
    git(target, "init", "--quiet")
    git(target, "config", "core.hooksPath", "/dev/null")
    git(target, "config", "commit.gpgsign", "false")
    git(target, "add", "--all")
    git(
        target,
        "-c",
        "user.name=Validation fixture",
        "-c",
        "user.email=validation@example.invalid",
        "commit",
        "--quiet",
        "--allow-empty",
        "--no-gpg-sign",
        "-m",
        "Validation snapshot",
    )


def nix_env():
    env = os.environ.copy()
    if shutil.which("gh"):
        token = subprocess.run(
            ["gh", "auth", "token"], capture_output=True, text=True, check=False
        )
        if token.returncode == 0 and token.stdout.strip():
            env["NIX_CONFIG"] = (
                env.get("NIX_CONFIG", "")
                + "\naccess-tokens = github.com="
                + token.stdout.strip()
            )
    return env


def execute(root, selection):
    failures = []

    def run(label, command, cwd=root, env=None, capture=False):
        display = shlex.join(command if len(command) < 40 else command[:8])
        if len(command) >= 40:
            display += " … (file list: hey check --plan)"
        print(f"==> {label}: {display}", flush=True)
        try:
            result = subprocess.run(
                command,
                cwd=cwd,
                env=env,
                text=True,
                check=False,
                stdout=subprocess.PIPE if capture else None,
            )
        except FileNotFoundError:
            print(
                f"FAIL {label}: missing {command[0]}; enter the repository dev shell.",
                file=sys.stderr,
            )
            failures.append(label)
            return None
        if result.returncode:
            failures.append(label)
            print(f"FAIL {label} (exit {result.returncode})", file=sys.stderr)
            return None
        return result.stdout.strip() if capture else True

    env = None
    if selection["hooks"] or selection["checks"] or selection["platform"]:
        env = nix_env()
    nix = ["nix", "--accept-flake-config"]
    build = nix + ["build", "--no-link", "--no-write-lock-file", "--print-build-logs"]
    if selection["hooks"]:
        config = run(
            "hook configuration",
            build + ["--print-out-paths", ".#pre-commit-config"],
            env=env,
            capture=True,
        )
        if config:
            files = [f for f in selection["files"] if (root / f).is_file()]
            if files:
                run(
                    "format and lint",
                    [
                        "prek",
                        "--config",
                        config.splitlines()[-1],
                        "run",
                        "--stage",
                        "pre-commit",
                        "--files",
                        *files,
                        "--no-progress",
                    ],
                )

    system = None
    if selection["checks"] or selection["platform"]:
        system = run(
            "Nix system",
            nix + ["eval", "--raw", "--impure", "--expr", "builtins.currentSystem"],
            capture=True,
        )
    if system:
        for name in selection["checks"]:
            run(name, build + [f".#checks.{system}.{name}"], env=env)
    target = selection["platform"]
    if target == "darwin":
        for host in ("MacTraitor-Pro", "Seqeratop"):
            run(
                host,
                nix
                + [
                    "eval",
                    "--raw",
                    "--no-write-lock-file",
                    f".#darwinConfigurations.{host}.system.drvPath",
                ],
                env=env,
            )
        if system:
            for name in DARWIN_CHECKS:
                run(name, build + [f".#checks.{system}.{name}"], env=env)
    elif target == "nixos":
        run(
            "full NixOS flake (including deployment and VM checks)",
            nix + ["flake", "check", "--no-write-lock-file", "--print-build-logs"],
            env=env,
        )
    elif target and system:
        name = {
            "herdr-vm": "vm-shell-herdr-vm-test",
            "services-vm": "vm-services-gatus-vm-test",
        }[target]
        run(target, build + [f".#checks.{system}.{name}"], env=env)

    if selection["packages"] or selection["integration"]:
        workspace = root / "packages/pi-packages"
        # Only test subprocesses opt out of signing their disposable Git fixtures.
        test_env = os.environ | {
            "GIT_CONFIG_COUNT": "1",
            "GIT_CONFIG_KEY_0": "commit.gpgsign",
            "GIT_CONFIG_VALUE_0": "false",
        }
        ts_files = [
            f
            for f in source_files(root)
            if any(
                f.startswith(f"packages/pi-packages/{p}/")
                for p in selection["packages"]
            )
            and f.endswith((".ts", ".tsx"))
        ]
        if ts_files:
            run(
                "TypeScript architecture",
                ["bash", "bin/lint-ts-architecture", *ts_files],
            )
        if run(
            "package dependencies",
            ["bun", "install", "--frozen-lockfile"],
            cwd=workspace,
        ):
            for package in selection["packages"]:
                directory = workspace / package
                scripts = json.loads((directory / "package.json").read_text()).get(
                    "scripts", {}
                )
                for script in ("typecheck", "test"):
                    if script in scripts:
                        run(
                            f"{package} {script}",
                            ["bun", "run", "--silent", script],
                            cwd=directory,
                            env=test_env,
                        )
            if selection["integration"]:
                run(
                    "package integration",
                    ["bun", "run", "--silent", "test:integration"],
                    cwd=workspace,
                    env=test_env,
                )
    changes = git(root, "diff", "--name-only", "HEAD").stdout.decode()
    if changes:
        print(
            "Validation changed snapshot files (your checkout is untouched):\n"
            + changes,
            file=sys.stderr,
        )
        print(
            "Apply intentional formatting with nix fmt, then rerun hey check.",
            file=sys.stderr,
        )
        failures.append("source mutation")
    if failures:
        print("FAILED: " + ", ".join(failures), file=sys.stderr)
        return 1
    print("PASS: selected validation completed; working tree untouched.")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--full",
        "--all",
        action="store_true",
        help="All portable checks and packages, including unchanged files",
    )
    parser.add_argument("--worktree", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument(
        "--base-ref",
        help="Diff merge-base against this ref (default: origin/main, else HEAD)",
    )
    parser.add_argument("--head-ref", default="HEAD", help=argparse.SUPPRESS)
    parser.add_argument(
        "--package",
        action="append",
        default=[],
        help="Explicit package QA (repeatable)",
    )
    parser.add_argument("--packages-only", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument(
        "--ci",
        action="store_true",
        help="Use VALIDATION_BASE; absent/zero base runs full; skip unaffected platform suites",
    )
    parser.add_argument(
        "--platform",
        choices=["darwin", "nixos", "herdr-vm", "services-vm"],
        help="Explicit host evaluation or VM suite, separate from portable checks",
    )
    parser.add_argument(
        "--plan",
        action="store_true",
        help="Print the selection as JSON without running tools or creating a snapshot",
    )
    parser.add_argument(
        "paths",
        nargs="*",
        help="Repository-relative changed-file scopes (task-owned paths)",
    )
    args = parser.parse_args(argv)
    if args.ci:
        base = args.base_ref or os.environ.get("VALIDATION_BASE", "")
        if base and set(base) != {"0"}:
            args.base_ref = base
        else:
            args.full = True
    if args.full and args.paths:
        parser.error(
            "--full cannot be scoped; use hey check [paths...] for changed work"
        )
    if (
        args.platform == "darwin"
        and not args.plan
        and (
            platform.system() != "Darwin"
            or platform.machine() not in ("arm64", "aarch64")
        )
    ):
        parser.error(
            "--platform darwin requires an aarch64 Darwin builder; nothing ran"
        )
    if args.platform in ("nixos", "herdr-vm", "services-vm") and (
        platform.system() != "Linux" or platform.machine() != "x86_64"
    ):
        parser.error(
            f"--platform {args.platform} requires an x86_64 Linux builder; nothing ran"
        )
    # Git hook environments must not redirect snapshot Git operations to the source index.
    for key in git(ROOT, "rev-parse", "--local-env-vars").stdout.decode().splitlines():
        os.environ.pop(key, None)
    os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
    try:
        selection = plan(ROOT, args)
        if args.plan:
            print(json.dumps(selection, indent=2))
            return 0
        print(
            f"Validation: {len(selection['files'])} files, {len(selection['checks'])} Nix checks, {len(selection['packages'])} packages",
            flush=True,
        )
        if not any(
            selection[k]
            for k in ("hooks", "checks", "packages", "integration", "platform")
        ):
            print("PASS: no changed work in scope.")
            return 0
        with tempfile.TemporaryDirectory(prefix="dotfiles-check-") as directory:
            target = Path(directory)
            before = fingerprint(ROOT)
            snapshot(ROOT, target)
            if fingerprint(ROOT) != before:
                raise ValueError("Source changed while copying; rerun hey check.")
            result = execute(target, selection)
            if fingerprint(ROOT) != before:
                raise ValueError(
                    "Source changed during validation; results are stale. Rerun hey check."
                )
            return result
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        detail = (
            error.stderr.decode(errors="replace")
            if isinstance(error, subprocess.CalledProcessError) and error.stderr
            else str(error)
        )
        print("Validation failed: " + detail, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
