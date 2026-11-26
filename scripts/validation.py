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
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# These are portable check derivations, not host evaluations or VM builds.
# Hook-owned tests are deliberately not repeated here.
CHECKS = {
    "orb-setup-tests": [
        ".agents/setup",
        ".agents/resume",
        ".agents/nix-env.sh",
        ".agents/orb-tools.nix",
        ".agents/mise-binary.nix",
        "tests/test_orb_setup.py",
        "packages/hey/*",
        "packages/bend/*",
        "bin/hey",
        "bin/agent-run",
        "scripts/validation.py",
    ],
    "validation-tests": [
        ".agents/mise-binary.nix",
        "scripts/validation.py",
        "scripts/run_validation_tests.py",
        "scripts/nuc_shipping.py",
        "tests/test_nuc_shipping.py",
        "config/amp-orbs/*",
        "scripts/amp-orb-pilot.sh",
        "tests/test_amp_orb_dispatch.py",
        "scripts/candidate_ci.py",
        "tests/test_candidate_ci.py",
        "scripts/nuc_rollout.py",
        "tests/test_nuc_rollout.py",
        "scripts/ci_check_cache.py",
        "scripts/ci_dependency_cache.py",
        "tests/test_ci_check_cache.py",
        "scripts/renovate_admission.py",
        "tests/test_renovate_admission.py",
        "scripts/beads_filter.py",
        "tests/test_beads_filter.py",
        "bin/amp-runner-sync",
        "config/amp/*",
        "tests/test_amp_runner_sync.py",
        "bin/hey",
        "bin/hey-task*",
        "packages/hey/*",
        "packages/bend/*",
        "mise.toml",
        "bin/hey.d/*",
        "modules/agents/pi/lib/_runtime-wrapper.nix",
        "tests/test_mise_tasks.py",
        "bin/qa-changed",
        "tests/test_validation.py",
        ".github/workflows/*",
        ".codex/hooks.json",
    ],
    "callstack-diff": [
        "packages/callstack-diff/*",
        "scripts/renovate_admission.py",
        ".github/workflows/renovate-admission.yml",
    ],
    "hey-native": [
        "bin/hey",
        "bin/hey-task*",
        "bin/prune-nuc-deploy-snapshots",
        "bin/write-nuc-deploy-revision",
        "packages/hey/*",
        "packages/bend/*",
        ".agents/mise-binary.nix",
    ],
    "hass-health-tests": ["modules/services/hass/*"],
    "gatus-alerting-tests": ["modules/services/gatus/*", "overlays/gatus/*"],
    "gatus-native-tests": ["modules/services/gatus/*", "overlays/gatus/*"],
    "zunit-tests": ["config/zsh/*", "packages/zunit/*"],
    "package-harness-tests": [
        "packages/package-harness/*",
        "packages/*/default.nix",
        "packages/*/patches/*",
    ],
    "package-policy-tests": [
        "renovate.json",
        "packages/*",
        "bin/check-package-layout",
        "bin/check-patch-locality",
        "bin/check-renovate-patch-paths",
        "bin/import-renovate-patch-repair",
        ".flue/*",
        ".github/workflows/renovate-patch-repair.yml",
        "tests/test_package_policy.py",
        "tests/test_oxlint_jev.py",
    ],
    "oxlint-jev": [
        "packages/oxlint-plugin-jev/*",
        "docs/agents/oxlint.md",
        "tests/test_oxlint_jev.py",
    ],
    "hunk-config-compatibility": [
        "config/hunk/*",
        "modules/shell/git/*",
        "overlays/hunk/*",
    ],
    "agent-run-tests": [
        "bin/agent-*",
        "bin/hey.d/agent/*",
        "tests/test_agent_run.py",
        "tests/test_skill_quality_validator.py",
        "skills/catalog/skill-quality/*",
    ],
    "done-delivery-tests": [
        "skills/catalog/done/*",
        "skills/flake.nix",
        "packages/bend/*",
        "scripts/check_done_bundle.py",
        "bin/hey.d/skills/amp-stage-done",
        "tests/done_bend.py",
        "tests/test_done_closeout.py",
        "tests/test_done_delivery.py",
        "tests/test_done_skill.py",
    ],
    "agent-docs-contract": [
        "AGENT_WORKFLOW.md",
        "docs/README.md",
        "docs/agent-guardrails.md",
        "docs/validation.md",
        "docs/agents/oxlint.md",
    ],
    "tldraw-api-tests": [
        "config/tldraw/*",
        "modules/desktop/apps/tldraw.nix",
        "skills/catalog/tldraw-offline/*",
        "tests/test_tldraw_api.py",
    ],
    "agent-mcp-tests": [
        "config/agents/mcp.nix",
        "config/agents/reconcile_mcp.py",
        "modules/agents/mcp/*",
        "tests/test_agent_mcp.py",
        "hosts/*/default.nix",
    ],
    "agent-instruction-tests": [
        "AGENTS.md",
        "bin/check-agent-context-layout",
        "tests/test_agent_context_layout.py",
        "config/agents/AGENTS.md",
        "docs/agents/unslop.md",
        "skills/catalog/unslop/*",
        "skills/flake.nix",
        "skills/flake.lock",
        "skills/mattpocock-skills.json",
        "bin/bootstrap",
        "config/agents/core.md",
        "config/codex/config.toml",
        "config/opencode/opencode.jsonc",
        "modules/agents/claude/*",
        "modules/agents/codex/*",
        "modules/agents/opencode/*",
        "modules/agents/pi/*",
        "modules/agents/plannotator/*",
        "modules/agents/retired-moshi/*",
        "tests/test_retired_moshi.py",
        "hosts/nuc/secrets/moshi-hook-secrets-json.age",
        "hosts/nuc/secrets/secrets.nix",
        "overlays/pi/*",
        "tests/agent-instruction-config.nix",
        "tests/test_agent_instruction_wiring.py",
        "tests/test_agent_response_contract.py",
        "tests/test_pi_update.py",
        "tests/test_codex_model_config.py",
    ],
    "claude-session-budget-tests": [
        "config/claude/session-budget-hook.py",
        "modules/agents/claude/*",
        "tests/fixtures/claude-session-budget/*",
        "tests/test_claude_session_budget.py",
    ],
    "agent-skills-marker-migration-tests": [
        "modules/agents/skills/*",
        "tests/test_agent_skills_marker_migration.py",
    ],
    "ast-grep-tests": ["ast-grep/*", "sgconfig.yml"],
    "displayctl-tests": ["packages/displayctl/*"],
    "displayctl-tnote-integration": ["packages/displayctl/*"],
    "trmnl-agent-message-structure": ["config/trmnl/agent-message/*"],
    "nix-private-github": [
        "bin/nix-private-github",
        "bin/tests/*nix_private*",
        "bin/tests/nix-private*",
    ],
    "hermes-cron-executor-source-tests": [
        "tests/test_hermes_cron_executors.py",
        "scripts/verify_hermes_retirement.py",
        "hosts/nuc/*",
        "modules/agents/hermes/*",
    ],
    "pi-herdr-settings-tests": [
        "modules/agents/pi/*",
        "modules/shell/herdr/*",
        "config/pi/settings.jsonc",
    ],
    "herdr-native-tests": [
        "modules/shell/herdr/*",
        "config/herdr/*",
        "bin/herdr-studios",
        "tests/test_herdr_native*.py",
        "tests/test_herdr_studios_native.py",
    ],
    "screentime-backup-cli-tests": ["packages/screentime-backup/*"],
    "discrawl-backup-cli-tests": ["packages/discrawl-backup/*"],
    "nuc-deployment-provenance": [
        "hosts/nuc/_tests/deployment-provenance.nix",
        "bin/hey.d/nuc/*",
        "bin/write-nuc-deploy-revision",
        "packages/hey/nuc-*.bend",
        "packages/hey/snapshot-*.bend",
    ],
    "nuc-hermes-displayctl-wiring": ["hosts/nuc/*", "packages/displayctl/*"],
    "nuc-hermes-cron-failure-summary": ["tests/test_hermes_cron_failure_summary.py"],
}

# These checks build complete applications or their toolchains. Keep them
# explicit instead of compiling unrelated native packages on routine CI pushes.
PACKAGE_BUILD_CHECKS = {
    "callstack-diff",
    "hunk-config-compatibility",
    "gatus-native-tests",
    "displayctl-tnote-integration",
}

LINUX_CHECKS = {
    "nuc-hermes-retired": ["hosts/nuc/*", "modules/services/hass/*"],
    "ha-automation-assertions": [
        "modules/services/hass/*",
        "hosts/nuc/*",
        "scripts/validation.py",
    ],
    "ha-behavior-tests": [
        "modules/services/hass/*",
        "hosts/nuc/*",
        "scripts/validation.py",
    ],
    "ha-robot-cleaning-tests": [
        "modules/services/hass/*",
        "hosts/nuc/*",
        "scripts/validation.py",
    ],
}

DARWIN_CHECKS = [
    "rex-package-wiring",
    "mactraitor-fail-closed-activation",
    "apple-container-pilot-assertions",
    "audio-priority-bar-regressions",
    "screentime-backup-darwin-assertions",
    "discrawl-backup-darwin-assertions",
    "darwin-tailscaled-owner-assertions",
    "tinybar-darwin-assertions",
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


def comparison_base(root, base=None, head="HEAD"):
    if base is None:
        base = (
            "origin/main"
            if git(root, "rev-parse", "--verify", "origin/main", check=False).returncode == 0
            else "HEAD"
        )
    return git(root, "merge-base", base, head).stdout.decode().strip()


def selected_files(root, base=None, head="HEAD", full=False, scopes=()):
    if full:
        files = source_files(root)
    else:
        base = comparison_base(root, base, head)
        files = names(
            git(root, "diff", "--name-only", "--no-renames", "-z", base, head)
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


def hygiene(root, files, base):
    """Local, read-only lint pilot; diagnostics and missing tools are advisory."""
    batches = {"ruff": [], "shellcheck": [], "ast-grep": []}
    changed = {}
    for name in files:
        path = root / name
        if not path.is_file() or path.is_symlink() or "/skills/" in name:
            continue
        if (name.startswith("modules/") and path.suffix == ".nix") or (
            name.startswith("config/nvim/") and path.suffix == ".lua"
        ):
            tool = "ast-grep"
        else:
            # Native linters cover entrypoints, not injected application globals
            # or interactive Zsh config.
            if not name.startswith(("bin/", "scripts/", ".agents/")):
                continue
            first = path.read_bytes().split(b"\n", 1)[0]
            if path.suffix == ".py" or re.match(rb"#![^\n]*\bpython[\d.]*\b", first):
                tool = "ruff"
            elif re.match(rb"#![^\n]*\b(?:ba)?sh\b", first):
                tool = "shellcheck"
            else:
                continue
        batches[tool].append(name)
        if git(root, "cat-file", "-e", f"{base}:{name}", check=False).returncode:
            changed[name] = [(1, len(path.read_bytes().splitlines()) + 1)]
        else:
            diff = git(root, "diff", "--no-ext-diff", "--unified=0", base, "--", name).stdout
            changed[name] = [
                (int(start), int(start) + int(count or b"1") - 1)
                for start, count in re.findall(
                    rb"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", diff, re.MULTILINE
                )
                if count != b"0"
            ]
    commands = {
        "ruff": ["ruff", "check", "--no-cache", "--isolated", "--output-format=json",
                 "--select=F821,F822,F823,E9,B006,B023"],
        # --include also hides parse errors. Select from JSON instead.
        "shellcheck": ["shellcheck", "--norc", "--format=json"],
        # Separate config: experimental rules never enter the blocking scan.
        "ast-grep": ["ast-grep", "scan", "--config", "ast-grep/advisory.yml",
                     "--json=compact", "--threads=1"],
    }
    for tool, paths in batches.items():
        if not paths:
            continue
        started = time.monotonic()
        try:
            result = subprocess.run(commands[tool] + ["--", *paths], cwd=root,
                                    capture_output=True, text=True, check=False)
            if result.returncode not in (0, 1):
                print(f"ADVISORY {tool}: could not lint: {result.stderr.strip()}")
                continue
            diagnostics = json.loads(result.stdout)
            reported = 0
            for item in diagnostics:
                if tool == "ruff":
                    name = Path(item["filename"]).relative_to(root).as_posix()
                    line, end = item["location"]["row"], item["end_location"]["row"]
                    code = item["code"]
                    syntax = code == "invalid-syntax"
                elif tool == "ast-grep":
                    name = Path(item["file"])
                    name = (name.relative_to(root) if name.is_absolute() else name).as_posix()
                    line = item["range"]["start"]["line"] + 1
                    end = item["range"]["end"]["line"] + 1
                    code, syntax = item["ruleId"], False
                else:
                    name, line, end = item["file"], item["line"], item["endLine"]
                    code = f"SC{item['code']}"
                    syntax = item["level"] == "error" and 1000 <= item["code"] < 2000
                    if not syntax and item["code"] not in (2086, 2046, 2155):
                        continue
                if syntax or any(line <= last and end >= first for first, last in changed[name]):
                    print(f"ADVISORY {name}:{line}: {code} {item['message']}")
                    reported += 1
            print(f"{tool}: {len(paths)} files, {reported} advisory diagnostics, "
                  f"{time.monotonic() - started:.3f}s")
        except FileNotFoundError:
            print(f"ADVISORY {tool}: not installed; skipped (no automatic install).")
        except (ValueError, KeyError, TypeError) as error:
            print(f"ADVISORY {tool}: could not read diagnostics: {error}")
    print("Hygiene pilot only; no validation ran. Diagnostics do not fail this command.")
    return 0


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
        for p in workspace.glob("pi-*/package.json")
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
    unknown = selected - available.keys()
    if unknown:
        raise ValueError("Unknown packages: " + ", ".join(sorted(unknown)))
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
            "flue": False,
            "platform": target,
        }
    checks = []
    if not args.packages_only:
        available_checks = CHECKS
        if platform.system() == "Linux" and platform.machine() == "x86_64":
            available_checks = CHECKS | LINUX_CHECKS
        checks = [
            name
            for name, patterns in available_checks.items()
            if args.full
            or matches(
                files, patterns + ["flake.nix", "flake.lock", "lib/*", "overlays/*"]
            )
        ]
    deferred = []
    if not args.package_builds:
        deferred = [name for name in checks if name in PACKAGE_BUILD_CHECKS]
        checks = [name for name in checks if name not in PACKAGE_BUILD_CHECKS]
    return {
        "files": files,
        "hooks": bool(files) and not args.packages_only,
        "checks": checks,
        "deferred_checks": deferred,
        "packages": packages,
        "integration": integration,
        "flue": not args.packages_only
        and (
            args.full
            or matches(
                files,
                [
                    ".flue/*",
                    "packages/flue-evlog/*",
                    ".github/workflows/renovate-patch-repair.yml",
                    "scripts/validation.py",
                ],
            )
        ),
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
    # source_files already excludes untracked ignored state. Force-add its
    # copies so files tracked by the source repo remain tracked even when a
    # source .gitignore pattern also matches them.
    git(target, "add", "--all", "--force")
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


def nix_env(token=""):
    env = os.environ.copy()
    if not token and shutil.which("gh"):
        token_result = subprocess.run(
            ["gh", "auth", "token"], capture_output=True, text=True, check=False
        )
        if token_result.returncode == 0:
            token = token_result.stdout.strip()
    if token:
        env["NIX_CONFIG"] = (
            env.get("NIX_CONFIG", "") + "\naccess-tokens = github.com=" + token
        )
    return env


def execute(root, selection, github_token=""):
    failures = []
    cache_directory = os.environ.get("CI_CHECK_CACHE_DIR", "")
    cache_outputs = []

    def run(label, command, cwd=root, env=None, capture=False):
        display = shlex.join(command if len(command) < 40 else command[:8])
        if len(command) >= 40:
            display += " … (file list: hey check --plan)"
        print(f"==> {label}: {display}", flush=True)
        started = time.monotonic()
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
        print(
            f"<== {label}: exit {result.returncode}, {time.monotonic() - started:.3f}s",
            flush=True,
        )
        if result.returncode:
            failures.append(label)
            print(f"FAIL {label} (exit {result.returncode})", file=sys.stderr)
            return None
        return result.stdout.strip() if capture else True

    env = None
    if selection["hooks"] or selection["checks"] or selection["platform"]:
        env = nix_env(github_token)
    nix = ["nix", "--accept-flake-config"]
    build = nix + ["build", "--no-link", "--no-write-lock-file", "--print-build-logs"]
    if selection["hooks"]:
        # Path policy must see directory and dangling symlinks that formatters skip.
        paths = [
            f for f in selection["files"]
            if (root / f).is_file() or (root / f).is_symlink()
        ]
        if paths:
            run(
                "agent context paths",
                ["bash", "bin/check-agent-context-layout", *paths],
            )
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
    if system and selection["checks"]:
        # One evaluator and one dependency graph. Nix schedules independent
        # builds within its configured job/core limits, including after failures.
        outputs = run(
            "Nix checks",
            build
            + ["--keep-going"]
            + (["--print-out-paths"] if cache_directory else [])
            + [f".#checks.{system}.{name}" for name in selection["checks"]],
            env=env,
            capture=bool(cache_directory),
        )
        if cache_directory and outputs:
            for path in outputs.splitlines():
                name = Path(path).name[33:]
                if name in selection["checks"]:
                    cache_outputs.append(f"{name}={path}")
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
                installable = f".#checks.{system}.{name}"
                run(name, build + [installable], env=env)
    elif target == "nixos":
        run(
            "full NixOS flake (including deployment and VM checks)",
            nix + ["flake", "check", "--no-write-lock-file", "--print-build-logs"],
            env=env,
        )
    elif target and system:
        name = {
            "services-vm": "vm-services-gatus-vm-test",
        }[target]
        run(target, build + [f".#checks.{system}.{name}"], env=env)

    if selection["flue"]:
        adapter = root / "packages/flue-evlog"
        if run(
            "Flue adapter dependencies",
            ["npm", "ci", "--ignore-scripts"],
            cwd=adapter,
        ) and run("Flue adapter", ["npm", "run", "check"], cwd=adapter):
            workspace = root / ".flue"
            if run(
                "Flue dependencies",
                ["npm", "ci", "--ignore-scripts"],
                cwd=workspace,
            ):
                run("Flue observability", ["npm", "run", "check"], cwd=workspace)

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
    if cache_directory:
        # Cache publication is optional; only the real check results decide CI.
        subprocess.run(
            [
                sys.executable,
                "-m",
                "scripts.ci_check_cache",
                "save",
                cache_directory,
                *cache_outputs,
            ],
            cwd=root,
            check=False,
        )
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
        "--package-builds",
        action="store_true",
        help="Include affected native application builds and packaged integration tests",
    )
    parser.add_argument(
        "--ci",
        action="store_true",
        help="Use VALIDATION_BASE; absent/zero base runs full; skip unaffected platform suites",
    )
    parser.add_argument(
        "--platform",
        choices=["darwin", "nixos", "services-vm"],
        help="Explicit host evaluation or VM suite, separate from portable checks",
    )
    parser.add_argument(
        "--plan",
        action="store_true",
        help="Print the selection as JSON without running tools or creating a snapshot",
    )
    parser.add_argument(
        "--hygiene",
        action="store_true",
        help="Local advisory lint pilot only; does not run validation",
    )
    parser.add_argument(
        "paths",
        nargs="*",
        help="Repository-relative changed-file scopes (task-owned paths)",
    )
    args = parser.parse_args(argv)
    if args.hygiene and (args.ci or args.full or args.platform or args.package or args.package_builds or args.packages_only or args.plan):
        parser.error("--hygiene is a local changed-code pilot; use it separately from validation modes")
    # A missing CI baseline expands source coverage, not permission to compile
    # applications. Only an explicit --full or --package-builds does that.
    args.package_builds = args.package_builds or args.full
    github_token = os.environ.pop("NIX_GITHUB_TOKEN", "").strip()
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
    if args.platform in ("nixos", "services-vm") and not args.plan and (
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
        if args.hygiene:
            files = selected_files(ROOT, args.base_ref, args.head_ref, scopes=args.paths)
            return hygiene(ROOT, files, comparison_base(ROOT, args.base_ref, args.head_ref))
        selection = plan(ROOT, args)
        if args.plan:
            print(json.dumps(selection, indent=2))
            return 0
        print(
            f"Validation: {len(selection['files'])} files, {len(selection['checks'])} Nix checks, {len(selection['packages'])} packages",
            flush=True,
        )
        if selection.get("deferred_checks"):
            print(
                "Package builds deferred (use --package-builds or --full): "
                + ", ".join(selection["deferred_checks"]),
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
            result = execute(target, selection, github_token)
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
