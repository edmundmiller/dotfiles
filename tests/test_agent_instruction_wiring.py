import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OMP_MODULE = ROOT / "modules" / "agents" / "omp" / "default.nix"
CODEX_MODULE = ROOT / "modules" / "agents" / "codex" / "default.nix"
CLAUDE_MODULE = ROOT / "modules" / "agents" / "claude" / "default.nix"
PI_MODULE = ROOT / "modules" / "agents" / "pi" / "default.nix"
PI_HOME_FILES = ROOT / "modules" / "agents" / "pi" / "lib" / "_home-files.nix"
PI_SETTINGS_CHECK = ROOT / "modules" / "agents" / "pi" / "test-settings-json.sh"
PI_SETTINGS_VALIDATOR = ROOT / "modules" / "agents" / "pi" / "validate-settings-json.py"
OPENCODE_MODULE = ROOT / "modules" / "agents" / "opencode" / "default.nix"
OPENCODE_CONFIG = ROOT / "config" / "opencode" / "opencode.jsonc"
BOOTSTRAP = ROOT / "bin" / "bootstrap"
OMP_CORE = ROOT / "config" / "agents" / "core.md"
OMP_CONFIG = ROOT / "config" / "omp" / "config.yml"
LEGACY_RULES = ROOT / "config" / "agents" / "rules"
FIX_AGENTS_COMMAND = ROOT / "config" / "omp" / "commands" / "fix-agents-md.md"
THREAD_INTROSPECTION = ROOT / "config" / "omp" / "prompts" / "thread-introspection.md"
CODING_STANDARDS = ROOT / "CODING_STANDARDS.md"
TEST_QUALITY_SKILL = ROOT / "skills" / "catalog" / "test-quality" / "SKILL.md"
PI_NIX_SYNTAX_SKILL = ROOT / ".agents" / "skills" / "pi-nix-syntax" / "SKILL.md"
SKILLS_FLAKE = ROOT / "skills" / "flake.nix"
SKILLS_COMMAND = ROOT / "bin" / "hey.d" / "skills-catalog.nu"


class AgentInstructionWiringTests(unittest.TestCase):
    def test_every_global_instruction_surface_uses_the_bounded_core(self) -> None:
        core = OMP_CORE.read_text()
        normalized_core = " ".join(core.split())
        omp_module = OMP_MODULE.read_text()

        self.assertLessEqual(len(core.split()), 220)
        for invariant in (
            "Preserve unrelated work and stay within the user's requested scope.",
            "Do not infer authority",
            "Distinguish verified facts, user-provided facts, assumptions, and unknowns.",
            "Do not claim completion without fresh evidence",
        ):
            self.assertIn(invariant, normalized_core)

        self.assertIn('agentCore = builtins.readFile "${configDir}/agents/core.md";', omp_module)
        self.assertIn('home.file.".omp/agent/AGENTS.md".text = agentCore;', omp_module)
        self.assertNotIn('home.file.".omp/agent/AGENTS.md".text = concatenatedRules;', omp_module)
        self.assertNotIn('home.file.".omp/agent/rules/incremental-architecture.md"', omp_module)
        for rule_name in (
            "working-with-jj.md",
            "commit-house-style.md",
            "pr-house-style.md",
            "ci-watch.md",
        ):
            self.assertIn(f'home.file.".omp/agent/rules/{rule_name}"', omp_module)

        module_targets = {
            CODEX_MODULE: '".codex/AGENTS.md".text = agentCore;',
            CLAUDE_MODULE: '".claude/CLAUDE.md".text = agentCore;',
        }
        for module, target in module_targets.items():
            with self.subTest(module=module):
                source = module.read_text()
                self.assertIn(
                    'agentCore = builtins.readFile "${configDir}/agents/core.md";',
                    source,
                )
                self.assertIn(target, source)
                self.assertNotIn("rulesDir", source)
                self.assertNotIn("concatenatedRules", source)

        pi_module = PI_MODULE.read_text()
        pi_home_files = PI_HOME_FILES.read_text()
        self.assertIn(
            'agentCore = builtins.readFile "${configDir}/agents/core.md";',
            pi_module,
        )
        self.assertIn("agentCore", pi_home_files)
        self.assertIn('".pi/agent/AGENTS.md".text = agentCore;', pi_home_files)
        self.assertNotIn("rulesDir", pi_module)
        self.assertNotIn("concatenatedRules", pi_module + pi_home_files)

        opencode_module = OPENCODE_MODULE.read_text()
        self.assertIn(
            '"opencode2/opencode/AGENTS.md".source = "${configDir}/agents/core.md";',
            opencode_module,
        )
        self.assertNotIn('"opencode2/opencode/rules"', opencode_module)
        self.assertNotIn('"instructions"', OPENCODE_CONFIG.read_text())

        bootstrap = BOOTSTRAP.read_text()
        self.assertIn('config/agents/core.md', bootstrap)
        self.assertNotIn('config/agents/rules', bootstrap)
        self.assertFalse(LEGACY_RULES.exists())
        self.assertNotIn("For ADHD resources", core)

    def test_headless_bootstrap_links_shared_catalog_to_neutral_target(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            dotfiles = root / "dotfiles"
            fake_bin = root / "bin"
            skill = dotfiles / "skills" / "catalog" / "test-quality"
            second_skill = dotfiles / "skills" / "catalog" / "done"
            invalid_skill = dotfiles / "skills" / "catalog" / "missing-manifest"
            core = dotfiles / "config" / "agents" / "core.md"

            home.mkdir()
            fake_bin.mkdir()
            skill.mkdir(parents=True)
            second_skill.mkdir()
            invalid_skill.mkdir()
            core.parent.mkdir(parents=True)
            (skill / "SKILL.md").write_text("---\nname: test-quality\n---\n")
            (second_skill / "SKILL.md").write_text("---\nname: done\n---\n")
            (dotfiles / "skills" / "catalog" / "README.md").write_text("catalog\n")
            core.write_text("thin core\n")

            preserved = home / ".agents" / "skills" / "done"
            preserved.mkdir(parents=True)
            (preserved / "user-owned").write_text("keep\n")

            fake_nix = fake_bin / "nix"
            fake_nix.write_text(
                f"#!{sys.executable}\n"
                "import sys\n"
                'if sys.argv[1:] == ["--version"]:\n'
                '    print("nix test")\n'
            )
            fake_nix.chmod(0o755)

            env = os.environ.copy()
            env.update(
                HOME=str(home),
                DOTFILES_DIR=str(dotfiles),
                PATH=f"{fake_bin}:{env['PATH']}",
            )
            results = [
                subprocess.run(
                    ["bash", str(BOOTSTRAP)],
                    env=env,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                for _ in range(2)
            ]

            for result in results:
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertIn("linked 1 shared skills", result.stdout)
                self.assertIn("leaving existing non-symlink skill target", result.stdout)
            config_link = home / ".config" / "dotfiles"
            self.assertTrue(config_link.is_symlink())
            self.assertEqual(dotfiles.resolve(), config_link.resolve())
            installed = home / ".agents" / "skills" / "test-quality"
            self.assertTrue(installed.is_symlink())
            self.assertEqual(skill.resolve(), installed.resolve())
            self.assertEqual("keep\n", (preserved / "user-owned").read_text())
            self.assertFalse((preserved / "done").exists())
            self.assertFalse((home / ".agents" / "skills" / "missing-manifest").exists())
            self.assertFalse((home / ".agents" / "skills" / "README.md").exists())
            self.assertFalse((home / ".pi" / "agent" / "skills").exists())

    def test_pi_nix_syntax_routes_skills_to_current_catalogs(self) -> None:
        skill = PI_NIX_SYNTAX_SKILL.read_text()
        skills_flake = SKILLS_FLAKE.read_text()
        skills_lock = json.loads((ROOT / "skills" / "flake.lock").read_text())

        self.assertIn("skills/catalog/<skill-name>/SKILL.md", skill)
        self.assertIn(".agents/skills/<skill-name>/SKILL.md", skill)
        self.assertIn('skills.enableAll = [ "catalog" ];', skill)
        self.assertIn("package-native", skill)
        self.assertIn("cd .. && hey skills-sync", skill)
        self.assertNotIn("config/agents/skills", skill)
        self.assertNotIn('skills.enableAll = ["local"]', skill)

        self.assertTrue(PI_NIX_SYNTAX_SKILL.exists())
        self.assertFalse((ROOT / "skills" / "catalog" / "pi-nix-syntax").exists())
        self.assertIn("path = ./catalog;", skills_flake)
        self.assertIn('skills.enableAll = [ "catalog" ];', skills_flake)
        pi_route_start = skills_flake.index("extending-pi = {")
        pi_route = skills_flake[pi_route_start : pi_route_start + 180]
        self.assertIn('from = "pi-extensions";', pi_route)
        self.assertIn('meta.targets = [ "pi" ];', pi_route)

        pi_input = skills_lock["nodes"]["pi-extension-skills"]
        self.assertFalse(pi_input["flake"])
        self.assertTrue(pi_input["locked"]["rev"])
        self.assertTrue(pi_input["locked"]["narHash"])

    def test_test_quality_source_routes_stay_selective(self) -> None:
        core = OMP_CORE.read_text()
        standard = CODING_STANDARDS.read_text()
        skill = TEST_QUALITY_SKILL.read_text()
        claude_module = CLAUDE_MODULE.read_text()
        skills_flake = SKILLS_FLAKE.read_text()

        self.assertNotIn("tautological", core.lower())
        self.assertIn("Tautological tests", standard)
        self.assertIn("independent", skill.lower())
        self.assertIn("claude-test-quality-skill", claude_module)
        self.assertIn(
            'shared="$HOME/.agents/skills/test-quality"',
            claude_module,
        )
        self.assertIn('if [ ! -f "$shared/SKILL.md" ]; then', claude_module)
        self.assertIn('"dotfiles-agent-skills"', claude_module)

        target_start = skills_flake.index("targetEnabled = {")
        target_route = skills_flake[target_start : target_start + 420]
        self.assertIn("agents = true;", target_route)

        route_start = skills_flake.index("test-quality = {")
        route = skills_flake[route_start : route_start + 420]
        self.assertIn('from = "catalog";', route)
        self.assertIn('"agents"', route)
        self.assertIn('"hermes"', route)
        self.assertNotIn('"codex"', route)

    def test_skills_sync_has_no_retired_checkout_input(self) -> None:
        command = SKILLS_COMMAND.read_text()
        sync_start = command.index('def "main skills-sync"')
        bump_start = command.index('def "main skills-bump"')
        sync = command[sync_start:bump_start]

        self.assertNotIn("dotfiles-repo", command)
        self.assertIn("nix flake update skills-catalog", sync)
        self.assertIn("main rebuild", sync)

    def test_agents_md_use_guarded_hey_interfaces(self) -> None:
        root_agents = (ROOT / "AGENTS.md").read_text()
        for command in ("hey re", "hey skills-update", "hey skills-sync"):
            self.assertIn(command, root_agents)

        rejected = (
            "sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .",
            "nix flake update skills-catalog",
        )
        offenders = []
        for path in ROOT.rglob("AGENTS.md"):
            if any(part in {".git", "node_modules"} for part in path.parts):
                continue
            text = path.read_text()
            offenders.extend(
                f"{path.relative_to(ROOT)}: {command}"
                for command in rejected
                if command in text
            )

        self.assertEqual([], offenders)

    def test_omp_installs_fix_agents_md_prompt_template(self) -> None:
        prompt = FIX_AGENTS_COMMAND.read_text()
        module = OMP_MODULE.read_text()

        self.assertIn(
            "I want you to refactor my AGENTS.md file to follow progressive disclosure principles.",
            prompt,
        )
        self.assertIn("1. **Find contradictions**", prompt)
        self.assertIn("5. **Flag for deletion**", prompt)
        self.assertIn('home.file.".omp/agent/commands/fix-agents-md.md"', module)
        self.assertIn('source = "${configDir}/omp/commands/fix-agents-md.md";', module)

    def test_opencode_module_owns_its_v2_compatibility_alias(self) -> None:
        module = OPENCODE_MODULE.read_text()

        self.assertIn("opencodeV2ConfigDir", module)
        self.assertIn(
            '${pkgs.coreutils}/bin/ln -sfn "${opencodeV2ConfigDir}" "${opencodeV1ConfigDir}"',
            module,
        )

    def test_omp_config_uses_the_deployed_omp_18_registry(self) -> None:
        config = OMP_CONFIG.read_text()
        flake = (ROOT / "flake.nix").read_text()

        self.assertIn("methodOrder: [remote, soft]", config)
        self.assertIn("unexpectedStopDetection: smart", config)
        self.assertNotIn("strategy: context-full", config)
        self.assertIn("src=${self.packages.${system}.omp}", flake)

    def test_pi_settings_hook_executes_a_real_python_file(self) -> None:
        shell = PI_SETTINGS_CHECK.read_text()

        self.assertNotIn("<<'PY'", shell)
        self.assertIn("validate-settings-json.py", shell)
        self.assertTrue(PI_SETTINGS_VALIDATOR.is_file())

    def test_thread_introspection_cannot_recreate_global_startup_rules(self) -> None:
        prompt = THREAD_INTROSPECTION.read_text()
        module = OMP_MODULE.read_text()

        self.assertNotIn("config/agents/rules", prompt)
        self.assertIn(
            "Never edit `config/agents/core.md` from session mining.",
            prompt,
        )
        self.assertNotIn('path.startswith("config/agents/rules/")', module)

    def test_pre_commit_hooks_run_core_and_skill_checks(self) -> None:
        flake = (ROOT / "flake.nix").read_text()
        start = flake.index("agent-instructions = {")
        hook = flake[start : start + 1200]
        self.assertNotIn("check-agent-rules", hook)
        self.assertIn("skill-quality/scripts/validate.py", hook)
        self.assertIn('stages = [ "pre-commit" ]', hook)

        self.assertIn("omp-thin-harness = {", flake)
        self.assertIn("tests/test_omp_ttsr_rules.py", flake)
        self.assertIn("tests/test_agent_instruction_wiring.py", flake)
        self.assertIn(r"config/agents/core\\.md", flake)


if __name__ == "__main__":
    unittest.main()
