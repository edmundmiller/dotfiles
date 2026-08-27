import inspect
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NUC_CONFIG = ROOT / "hosts" / "nuc" / "default.nix"
RUNBOOK = ROOT / "docs" / "runbooks" / "deploy-nuc.md"
HERMES_OVERLAY = ROOT / "overlays" / "hermes-agent" / "default.nix"
HERMES_DASHBOARD_TEST = ROOT / "hosts" / "nuc" / "_tests" / "hermes-dashboard-enabled.nix"
HERMES_CRON_NIX_TEST = ROOT / "hosts" / "nuc" / "_tests" / "hermes-cron-executors.nix"


_OPENERS = {"(": ")", "[": "]", "{": "}"}
_CLOSERS = {closing: opening for opening, closing in _OPENERS.items()}


def _nix_structure(source: str) -> tuple[list[bool], dict[int, int]]:
    """Return code-byte masks and matching delimiters for a Nix source file."""

    code = [True] * len(source)
    matching: dict[int, int] = {}
    stack: list[tuple[str, int]] = []

    def mask(start: int, end: int) -> None:
        code[start:end] = [False] * (end - start)

    i = 0
    while i < len(source):
        if source.startswith("/*", i):
            end = source.find("*/", i + 2)
            end = len(source) if end < 0 else end + 2
            mask(i, end)
            i = end
            continue
        if source[i] == "#":
            end = source.find("\n", i)
            end = len(source) if end < 0 else end
            mask(i, end)
            i = end
            continue
        if source.startswith("''", i):
            mask(i, i + 2)
            i += 2
            while i < len(source):
                if source.startswith("'''", i):
                    mask(i, i + 3)
                    i += 3
                    continue
                if source.startswith("''", i):
                    escaped = source[i + 2 : i + 3] in {"$", "\\"}
                    mask(i, i + 2)
                    i += 2
                    if not escaped:
                        break
                    continue
                code[i] = False
                i += 1
            continue
        if source[i] == '"':
            mask(i, i + 1)
            i += 1
            while i < len(source):
                if source[i] == "\\":
                    mask(i, min(i + 2, len(source)))
                    i += 2
                else:
                    closing = source[i] == '"'
                    mask(i, i + 1)
                    i += 1
                    if closing:
                        break
            continue

        char = source[i]
        if char in _OPENERS:
            stack.append((char, i))
        elif char in _CLOSERS and stack and stack[-1][0] == _CLOSERS[char]:
            _, opening = stack.pop()
            matching[opening] = i
        i += 1

    return code, matching


def _stack_before(source: str, code: list[bool], position: int) -> list[str]:
    stack: list[str] = []
    for i, char in enumerate(source[:position]):
        if not code[i]:
            continue
        if char in _OPENERS:
            stack.append(char)
        elif char in _CLOSERS and stack and stack[-1] == _CLOSERS[char]:
            stack.pop()
    return stack


def _checks_span(source: str, code: list[bool]) -> tuple[int, int]:
    checks_match = next(
        match for match in re.finditer(r"\bchecks\s*=", source) if code[match.start()]
    )
    equals = source.index("=", checks_match.start(), checks_match.end())
    stack = _stack_before(source, code, equals + 1)
    base_depth = len(stack)

    for i in range(equals + 1, len(source)):
        if not code[i]:
            continue
        char = source[i]
        if char in _OPENERS:
            stack.append(char)
        elif char in _CLOSERS and stack and stack[-1] == _CLOSERS[char]:
            stack.pop()
        elif char == ";" and len(stack) == base_depth:
            return checks_match.start(), i + 1
    raise AssertionError("checks assignment has no structural terminator")


def _linux_guard_ranges(
    source: str, code: list[bool], matching: dict[int, int], span: tuple[int, int]
) -> list[tuple[int, int]]:
    ranges = []
    guard_pattern = re.compile(
        r'lib\.optionalAttrs\s*\(\s*system\s*==\s*"x86_64-linux"\s*\)'
    )
    for match in guard_pattern.finditer(source):
        if not code[match.start()]:
            continue
        argument = match.end()
        while argument < len(source) and source[argument].isspace():
            argument += 1
        if argument not in matching:
            continue
        end = matching[argument] + 1
        if span[0] <= match.start() < end <= span[1]:
            ranges.append((match.start(), end))
    return ranges


def _direct_check_references(
    source: str, span: tuple[int, int]
) -> list[tuple[str, int]]:
    patterns = (
        r"\bself\.nixosConfigurations\.nuc(?:[-.]\w+)*",
        r"\bself\.deploy\b",
    )
    references = []
    for pattern in patterns:
        for match in re.finditer(pattern, source):
            if span[0] <= match.start() < span[1]:
                references.append((match.group(), match.start()))
    return references


def _check_reference_layout(
    source: str,
) -> tuple[tuple[int, int], list[tuple[int, int]], list[tuple[str, int]]]:
    checks_start = source.index("checks =")
    checks_source = source[checks_start:]
    code, matching = _nix_structure(checks_source)
    relative_span = _checks_span(checks_source, code)
    relative_guards = _linux_guard_ranges(checks_source, code, matching, relative_span)
    span = (checks_start + relative_span[0], checks_start + relative_span[1])
    guards = [
        (checks_start + start, checks_start + end) for start, end in relative_guards
    ]
    references = _direct_check_references(source, span)
    return span, guards, references


def _bash_block_after(source: str, marker: str) -> str:
    marker_start = source.index(marker)
    previous_fence = source.rfind("```", 0, marker_start)
    fence_end = source.find("```", marker_start)
    if (
        previous_fence >= 0
        and source.startswith("```bash", previous_fence)
        and previous_fence < marker_start < fence_end
    ):
        fence_start = previous_fence
    else:
        fence_start = source.index("```bash", marker_start)
    block_start = source.index("\n", fence_start) + 1
    block_end = source.index("```", block_start)
    return source[block_start:block_end]


def _run_with_fake_commands(block: str, *, ssh_mode: str) -> tuple[int, str]:
    with tempfile.TemporaryDirectory(prefix="hermes-cron-runbook-") as temp:
        root = Path(temp)
        fake_bin = root / "bin"
        fake_bin.mkdir()
        log = root / "commands.log"
        (fake_bin / "ssh").write_text(
            "#!/bin/sh\n"
            'if [ "$SSH_MODE" = fail ]; then exit 23; fi\n'
            'case "$*" in\n'
            "  *configurationRevision*) printf '%s\\n' wrong-revision ;;\n"
            "esac\n"
            "exit 0\n",
            encoding="utf-8",
        )
        (fake_bin / "hey").write_text(
            '#!/bin/sh\nprintf \'%s\\n\' "$*" >> "$RUNBOOK_LOG"\n',
            encoding="utf-8",
        )
        (fake_bin / "nix").write_text(
            "#!/bin/sh\n"
            'printf \'nix %s\\n\' "$*" >> "$RUNBOOK_LOG"\n'
            'printf \'%s\\n\' \'{"locks":{"nodes":{"agents-workspace":{"locked":{"rev":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}}}}\'\n',
            encoding="utf-8",
        )
        (fake_bin / "git").write_text(
            "#!/bin/sh\n"
            'printf \'git %s\\n\' "$*" >> "$RUNBOOK_LOG"\n'
            'case "$*" in\n'
            "  \"rev-parse HEAD\") printf '%s\\n' 1111111111111111111111111111111111111111 ;;\n"
            "  *) exit 1 ;;\n"
            "esac\n",
            encoding="utf-8",
        )
        for command in ("ssh", "hey", "nix", "git"):
            (fake_bin / command).chmod(0o700)
        environment = os.environ.copy()
        environment.update(
            {
                "PATH": f"{fake_bin}:{environment['PATH']}",
                "RUNBOOK_LOG": str(log),
                "SSH_MODE": ssh_mode,
            }
        )
        result = subprocess.run(
            ["bash", "-c", block],
            cwd=ROOT,
            env=environment,
            text=True,
            capture_output=True,
        )
        return result.returncode, log.read_text(
            encoding="utf-8"
        ) if log.exists() else ""


class HermesCronExecutorTests(unittest.TestCase):
    def test_package_check_reads_python_modules_from_site_packages(self):
        flake = (ROOT / "flake.nix").read_text(encoding="utf-8")

        self.assertIn('"$package"/lib/python*/site-packages', flake)
        self.assertNotIn('"$package/share/hermes/hermes_cli/', flake)

    def test_dashboard_shared_package_assertion_follows_generated_units(self):
        source = HERMES_DASHBOARD_TEST.read_text(encoding="utf-8")

        self.assertIn("gatewayService.preStart", source)
        self.assertIn("expectedDashboardExec", source)
        self.assertIn('grep -Fq -- "$expectedDashboardExec" "$dashboard_start"', source)
        self.assertNotIn("builtins.elem hermesPackage (service.path", source)

    def test_cron_package_assertion_discards_store_context_before_infix(self):
        source = HERMES_CRON_NIX_TEST.read_text(encoding="utf-8")

        self.assertIn(
            'builtins.unsafeDiscardStringContext "exec ${hermesPackage}/bin/hermes cron tick"',
            source,
        )
        self.assertIn("hasInfix expectedCronTickExec bettyExecutorScript", source)

    def test_dashboard_package_assertion_avoids_store_context_regex(self):
        source = HERMES_DASHBOARD_TEST.read_text(encoding="utf-8")

        self.assertIn("expectedDashboardExec", source)
        self.assertNotIn(
            'pkgs.lib.hasInfix "${hermesPackage}/bin/hermes dashboard"',
            source,
        )

    def test_final_package_does_not_reapply_the_canonical_cron_stack(self):
        overlay = HERMES_OVERLAY.read_text(encoding="utf-8")
        flake = (ROOT / "flake.nix").read_text(encoding="utf-8")

        self.assertNotIn("test_hermes_cron_single_owner.py", overlay)
        self.assertIn("hermes-cron-single-owner", flake)
        self.assertIn("test_hermes_cron_external_executor.py", overlay)

    def test_overlay_keeps_nested_patch_paths_in_flake_source_context(self):
        overlay = HERMES_OVERLAY.read_text(encoding="utf-8")

        self.assertNotRegex(overlay, r"agentsWorkspacePatchRoot\s*\+\s*/")
        self.assertIn(
            'agentsWorkspacePatchRoot + "/buzz-stack-order.txt"',
            overlay,
        )

    def test_production_overlay_consumes_the_published_canonical_stack(self):
        overlay = HERMES_OVERLAY.read_text(encoding="utf-8")

        self.assertIn("buzz-stack-order.txt", overlay)
        self.assertRegex(
            overlay,
            r"patches\s*=\s*\(old\.patches or \[\s*\]\)\s*\+\+\s*"
            r"canonicalBuzzPatches\s*\+\+\s*auxiliaryHermesPatches\s*\+\+\s*"
            r"\[\s*dashboardLivenessPatch\s*\]",
        )
        self.assertIn("dashboardLivenessPatch", overlay)
        self.assertNotIn("/0001-buzz-01-thread-routing.patch", overlay)
        self.assertNotIn("/0006-gateway-cron-executor-ownership.patch", overlay)
        for contract in (
            "test_hermes_buzz_singuloid_pilot.py",
            "test_hermes_gateway_profile_identity.py",
            "test_hermes_kanban_platform_toolset.py",
            "test_hermes_buzz_thread_isolation.py",
            "test_hermes_cron_external_executor.py",
            "test_hermes_dashboard_profile_liveness.py",
        ):
            self.assertIn(contract, overlay)

    def test_agents_workspace_url_and_lock_revision_match(self):
        flake = (ROOT / "flake.nix").read_text(encoding="utf-8")
        lock = json.loads((ROOT / "flake.lock").read_text(encoding="utf-8"))
        match = re.search(
            r'url = "github:edmundmiller/agents-workspace/([0-9a-f]{40})";',
            flake,
        )

        self.assertIsNotNone(match)
        self.assertEqual(
            match.group(1),
            lock["nodes"]["agents-workspace"]["locked"]["rev"],
        )

    def test_darwin_common_checks_do_not_evaluate_nuc_or_deploy(self):
        flake = (ROOT / "flake.nix").read_text(encoding="utf-8")
        span, guards, references = _check_reference_layout(flake)
        self.assertTrue(references, "the check set must retain NUC/deploy coverage")
        unguarded = [
            (reference, position)
            for reference, position in references
            if not any(start <= position < end for start, end in guards)
        ]
        self.assertEqual([], unguarded, "direct NUC/deploy checks escaped Linux gating")
        self.assertLess(span[0], span[1])

    def test_cron_executor_source_contract_is_wired_as_a_common_check(self):
        flake = (ROOT / "flake.nix").read_text(encoding="utf-8")
        span, guards, _ = _check_reference_layout(flake)
        source_position = flake.index("hermes-cron-executor-source-tests")
        self.assertTrue(span[0] <= source_position < span[1])
        self.assertFalse(
            any(start <= source_position < end for start, end in guards),
            "source-only contract must remain in the common checks set",
        )
        self.assertIn("python3 tests/test_hermes_cron_executors.py", flake)

    def test_nuc_cron_executor_check_is_linux_only(self):
        flake = (ROOT / "flake.nix").read_text(encoding="utf-8")
        _, guards, _ = _check_reference_layout(flake)
        check_position = flake.index("nuc-hermes-cron-executors = import")
        self.assertTrue(
            any(start <= check_position < end for start, end in guards),
            "NUC config checks must be nested in a Linux-only checks set",
        )

    def test_static_guard_proof_rejects_an_unscoped_nuc_check(self):
        flake = (ROOT / "flake.nix").read_text(encoding="utf-8")
        mutated = flake.replace(
            "checks =\n",
            "checks =\n            unscoped_probe = self.nixosConfigurations.nuc;\n",
            1,
        )
        span, guards, references = _check_reference_layout(mutated)
        unguarded = [
            reference
            for reference, position in references
            if not any(start <= position < end for start, end in guards)
        ]
        self.assertIn("self.nixosConfigurations.nuc", unguarded)

    def test_runbook_cron_readback_is_machine_asserted(self):
        runbook = RUNBOOK.read_text(encoding="utf-8")
        block = _bash_block_after(
            runbook, "After a deployment, read back all three markers"
        )

        self.assertIn('test "$hostname" = "nuc"', block)
        self.assertIn("python3 -", block)
        self.assertIn("json.load", block)
        self.assertIn("datetime.fromisoformat", block)
        self.assertIn("max_age_seconds", block)
        self.assertIn("systemctl show", block)
        for property_name in (
            "LoadState",
            "ActiveState",
            "UnitFileState",
            "Type",
            "User",
        ):
            self.assertIn(property_name, block)
        self.assertIn("hermes cron status", block)
        for profile in ("amosburton", "betty", "scintillate"):
            self.assertIn(f"hermes-{profile}-cron-tick.timer", block)
            self.assertIn(f"hermes-{profile}-cron-tick.service", block)
            self.assertIn(f"hermes-gateway-{profile}.service", block)
        self.assertIn('marker["kind"]', block)

    def test_runbook_has_strict_identity_and_staged_revision_gate(self):
        runbook = RUNBOOK.read_text(encoding="utf-8")
        prerequisites = _bash_block_after(
            runbook, "Before any remote check or mutating command"
        )
        self.assertIn('test "$hostname" = "nuc"', prerequisites)

        deploy = _bash_block_after(runbook, "## Deploy")
        self.assertLess(deploy.index("hostname"), deploy.index("hey nuc"))

        staged = _bash_block_after(runbook, "stage=nuc-buzz-scintillate")
        self.assertLess(staged.index("hostname"), staged.index("hey nuc-wt build"))
        revision_markers = ("configurationRevision", "expected_revision", "nix eval")
        self.assertTrue(
            all(marker in staged for marker in revision_markers),
            "staged source revision must be validated before activation",
        )
        revision_position = min(staged.index(marker) for marker in revision_markers)
        self.assertLess(revision_position, staged.index("hey nuc-wt dry-activate"))

    def test_marker_writer_uses_fixed_home_collision_safe_atomic_contract(self):
        config = NUC_CONFIG.read_text(encoding="utf-8")
        self.assertIn('hermesHome = "/var/lib/hermes-${profile}/.hermes";', config)
        self.assertIn('mktemp "$marker_dir/.executor.json.XXXXXX"', config)
        self.assertIn('if [ -d "$marker" ]', config)
        self.assertIn('mv --no-target-directory "$tmp" "$marker"', config)
        self.assertNotIn('marker_dir="$HERMES_HOME/cron"', config)
        self.assertNotIn('tmp="$marker.$$"', config)

    def test_marker_writer_rejects_a_directory_appearing_during_publish(self):
        config = NUC_CONFIG.read_text(encoding="utf-8")
        self.assertIn('mv --no-target-directory "$tmp" "$marker"', config)

    def test_marker_writer_checks_process_returncodes_and_diagnostics(self):
        source = (ROOT / "tests" / "test_hermes_cron_marker_writer.py").read_text(
            encoding="utf-8"
        )
        self.assertIn("process.returncode", source)
        self.assertIn('"stderr"', source)
        self.assertIn("concurrent marker writers failed", source)
        self.assertIn("refusing to replace executor marker directory", source)

    def test_marker_writer_rejects_profile_and_cron_symlink_aliases(self):
        config = NUC_CONFIG.read_text(encoding="utf-8")
        self.assertIn('if [ -L "$hermes_profile_home" ]', config)
        self.assertIn('if [ -L "$hermes_home" ]', config)
        self.assertIn('if [ -L "$marker_dir" ]', config)

    def test_runbook_identity_failure_stops_following_mutations(self):
        runbook = RUNBOOK.read_text(encoding="utf-8")
        block = _bash_block_after(runbook, "## Deploy")
        returncode, commands = _run_with_fake_commands(block, ssh_mode="fail")
        self.assertNotEqual(0, returncode)
        self.assertNotIn("nuc", commands)

    def test_runbook_staged_revision_failure_stops_activation(self):
        runbook = RUNBOOK.read_text(encoding="utf-8")
        block = _bash_block_after(runbook, "stage=nuc-buzz-scintillate")
        returncode, commands = _run_with_fake_commands(
            block, ssh_mode="revision-mismatch"
        )
        self.assertNotEqual(0, returncode)
        self.assertIn("nuc-wt build", commands)
        self.assertIn("git rev-parse HEAD", commands)
        self.assertIn("nix flake metadata --json", commands)
        self.assertNotIn("dry-activate", commands)
        self.assertNotIn("switch", commands)

    def test_runbook_revision_failure_is_reached_from_a_gitless_store_check(self):
        helper_source = inspect.getsource(_run_with_fake_commands)
        self.assertIn('(fake_bin / "git").write_text', helper_source)
        self.assertIn("rev-parse HEAD", helper_source)

    def test_runbook_status_asserts_healthy_external_ownership(self):
        runbook = RUNBOOK.read_text(encoding="utf-8")
        block = _bash_block_after(
            runbook, "After a deployment, read back all three markers"
        )
        self.assertIn("status_text", block)
        self.assertIn(
            "External cron executor is running: {timer_name}",
            block,
        )
        self.assertIn(
            "Jobs fire through the host-managed systemd timer",
            block,
        )
        self.assertIn(
            "External cron executor is not running",
            block,
        )
        self.assertIn(
            "Gateway is not running",
            block,
        )

    def test_amos_materializes_its_linear_credential_from_opnix(self) -> None:
        config = NUC_CONFIG.read_text(encoding="utf-8")
        amos_secrets = config.split("  hermesAmosburtonSecrets =", 1)[1].split(
            "  hermesScintillateSecrets =", 1
        )[0]

        self.assertIn(
            "reference = amosburtonAgentSpec.hermes.dotenvReferences.LINEAR_API_KEY;",
            config,
        )
        self.assertIn('envVar = "LINEAR_API_KEY";', amos_secrets)
        self.assertIn('envVar = "HERMES_MCP_BEARER_TOKEN_LINEAR";', amos_secrets)
        self.assertEqual(
            2,
            amos_secrets.count(
                'path = "/var/lib/opnix/secrets/amosburtonLinearApiKey";'
            ),
        )

    def test_amos_uses_the_patched_canonical_cron_executor(self) -> None:
        config = NUC_CONFIG.read_text(encoding="utf-8")

        self.assertIn(
            'hermesAgentBase = pkgs.llm-agents."hermes-agent";',
            config,
        )
        self.assertIn('envVar = "LINEAR_API_KEY";', config)
        self.assertIn('envVar = "HERMES_MCP_BEARER_TOKEN_LINEAR";', config)
        self.assertIn('path = "/var/lib/opnix/secrets/amosburtonLinearApiKey";', config)
        self.assertIn("hermesAmosburtonSecretsMaterialize", config)
        self.assertNotIn("unset HERMES_MCP_BEARER_TOKEN_LINEAR", config)
        self.assertIn("systemd.services.hermes-amosburton-cron-tick", config)
        self.assertIn(
            'ExecStart = "${hermesAgentBase}/bin/hermes cron tick";',
            config,
        )
        self.assertNotIn("amosburtonHermesLauncher =", config)
        self.assertIn("systemd.timers.hermes-amosburton-cron-tick", config)


if __name__ == "__main__":
    unittest.main()
