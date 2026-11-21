import json
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parents[1]


class PackagePolicyTest(unittest.TestCase):
    def test_packages_do_not_fetch_git_during_evaluation(self):
        offenders = [
            str(path.relative_to(ROOT))
            for path in (ROOT / "packages").rglob("*.nix")
            if "allowBuiltinFetchGit = true;" in path.read_text()
        ]

        self.assertEqual(
            offenders,
            [],
            "Package Git dependencies must use outputHashes instead of evaluation-time fetchGit",
        )

    def test_hunk_metadata_matches_locked_input(self):
        metadata = json.loads((ROOT / "overlays/hunk/package-harness.json").read_text())
        self.assertIsInstance(metadata, dict, "Hunk metadata must be an object")
        for field in ("source", "ref"):
            self.assertIsInstance(metadata.get(field), str, f"Hunk metadata {field} must be a string")
        lock = json.loads((ROOT / "flake.lock").read_text())
        root_node_id = lock.get("root")
        self.assertIsInstance(root_node_id, str, "flake.lock root must be a node id")
        root_node = lock.get("nodes", {}).get(root_node_id)
        self.assertIsInstance(root_node, dict, "flake.lock root node is missing")
        hunk_node_id = root_node.get("inputs", {}).get("hunk")
        self.assertIsInstance(hunk_node_id, str, "flake.lock root input hunk must be a node id")
        original = lock.get("nodes", {}).get(hunk_node_id, {}).get("original")
        self.assertIsInstance(original, dict, "flake.lock Hunk original metadata is missing")
        for field in ("owner", "repo", "ref"):
            self.assertIsInstance(original.get(field), str, f"flake.lock Hunk original.{field} must be a string")
        self.assertEqual(metadata["source"], f"https://github.com/{original['owner']}/{original['repo']}.git")
        self.assertEqual(metadata["ref"], original["ref"])

        validated = subprocess.run(
            [
                sys.executable,
                ROOT / "bin/import-renovate-patch-repair",
                "hunk",
                ROOT,
                "--trusted-metadata",
                ROOT / "overlays/hunk/package-harness.json",
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(validated.returncode, 0, validated.stderr)

    def test_patch_locality_guard(self):
        script = ROOT / "bin/check-patch-locality"

        allowed = subprocess.run(
            [
                "bash",
                script,
                "packages/stack/patches/fix.patch",
                "overlays/hunk/patches/fix.patch",
                "skills/overlays/skill-doctor/pi-support.patch",
                "hosts/meshify/omarchy/patches/6844-amp-default-agent.patch",
                "hosts/meshify/omarchy/patches/6844-packaging.patch",
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(allowed.returncode, 0, allowed.stderr)
        locality_message = (
            "Patch must live at packages/<name>/patches/*.patch, "
            "overlays/<name>/patches/*.patch, skills/overlays/<name>/*.patch, "
            "or hosts/meshify/omarchy/patches/*.patch"
        )
        invalid_cases = [
            (["patches/fix.patch"], "patches/fix.patch"),
            (["misc/fix.patch"], "misc/fix.patch"),
            (["skills/fix.patch"], "skills/fix.patch"),
            (["skills/overlays/fix.patch"], "skills/overlays/fix.patch"),
            (
                ["skills/overlays/skill-doctor/nested/fix.patch"],
                "skills/overlays/skill-doctor/nested/fix.patch",
            ),
            (["packages/group/tool/patches/fix.patch"], "packages/group/tool/patches/fix.patch"),
            (
                ["hosts/other/omarchy/patches/fix.patch"],
                "hosts/other/omarchy/patches/fix.patch",
            ),
            (["hosts/meshify/omarchy/fix.patch"], "hosts/meshify/omarchy/fix.patch"),
            (
                ["hosts/meshify/omarchy/patches/nested/fix.patch"],
                "hosts/meshify/omarchy/patches/nested/fix.patch",
            ),
            (
                ["other/hosts/meshify/omarchy/patches/fix.patch"],
                "other/hosts/meshify/omarchy/patches/fix.patch",
            ),
            (
                ["hosts/meshify/omarchy/patches/fix.patch.backup"],
                "hosts/meshify/omarchy/patches/fix.patch.backup",
            ),
            (
                [
                    "hosts/meshify/omarchy/patches/6844-amp-default-agent.patch",
                    "misc/fix.patch",
                    "hosts/meshify/omarchy/patches/6844-packaging.patch",
                ],
                "misc/fix.patch",
            ),
            (
                [
                    "packages/stack/patches/fix.patch",
                    "misc/fix.patch",
                    "overlays/hunk/patches/fix.patch",
                ],
                "misc/fix.patch",
            ),
        ]
        for paths, offending_path in invalid_cases:
            with self.subTest(paths=paths):
                rejected = subprocess.run(["bash", script, *paths], capture_output=True, text=True)
                self.assertEqual(rejected.returncode, 1)
                self.assertIn(locality_message, rejected.stderr)
                self.assertIn(offending_path, rejected.stderr)

    def test_renovate_patch_repair_uses_trusted_agent_shell(self):
        agent = (ROOT / ".flue/agents/renovate-patch-repair.ts").read_text()
        command = "nix develop /trusted#agent --command pkg-check <target>"
        self.assertIn(command, agent)
        self.assertNotIn("nix develop --command pkg-check <target>", agent)

    def test_renovate_patch_repair_path_guard(self):
        script = ROOT / "bin/check-renovate-patch-paths"
        allowed = {
            "hunk": [
                "flake.nix",
                "flake.lock",
                "overlays/hunk/package-harness.json",
                "overlays/hunk/patches/0001-fix.patch",
            ],
        }

        for target, paths in allowed.items():
            with self.subTest(target=target):
                accepted = subprocess.run(
                    ["bash", script, target, *paths],
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(accepted.returncode, 0, accepted.stderr)

        rejected_cases = [
            ("hunk", ".github/workflows/renovate-patch-repair.yml"),
            ("hunk", "overlays/hunk/patches/nested/fix.patch"),
        ]
        for target, path in rejected_cases:
            with self.subTest(target=target, path=path):
                rejected = subprocess.run(
                    ["bash", script, target, path],
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(rejected.returncode, 1)
                self.assertIn(f"Renovate {target} repair cannot change: {path}", rejected.stderr)

        unknown = subprocess.run(
            ["bash", script, "other", "flake.nix"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(unknown.returncode, 2)
        self.assertIn("usage:", unknown.stderr)

    def test_renovate_patch_repair_importer(self):
        script = ROOT / "bin/import-renovate-patch-repair"
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            destination = root / "destination"
            for workspace in (source, destination):
                (workspace / "overlays/hunk/patches").mkdir(parents=True)
                (workspace / "flake.nix").write_text("old flake\n")
                (workspace / "flake.lock").write_text("old lock\n")

            old_harness = {
                "source": "https://example.test/hunk.git",
                "ref": "v1.0.0",
                "patches": ["patches/0001-delete.patch"],
                "checks": [["bun", "test"]],
            }
            (destination / "overlays/hunk/package-harness.json").write_text(
                json.dumps(old_harness, indent=2) + "\n"
            )
            (destination / "overlays/hunk/patches/0001-delete.patch").write_text("delete\n")
            (source / "flake.nix").write_text("malicious flake\n")
            (source / "flake.lock").write_text("malicious lock\n")
            (source / "overlays/hunk/package-harness.json").write_text("{}\n")
            (source / "overlays/hunk/patches/0002-add.patch").write_text("add\n")

            imported = subprocess.run(
                [sys.executable, script, "hunk", source, destination],
                capture_output=True,
                text=True,
            )
            self.assertEqual(imported.returncode, 0, imported.stderr)
            self.assertEqual((destination / "flake.nix").read_text(), "old flake\n")
            self.assertEqual((destination / "flake.lock").read_text(), "old lock\n")
            imported_harness = json.loads(
                (destination / "overlays/hunk/package-harness.json").read_text()
            )
            self.assertEqual(
                imported_harness,
                {**old_harness, "patches": ["patches/0002-add.patch"]},
            )
            self.assertFalse(
                (destination / "overlays/hunk/patches/0001-delete.patch").exists()
            )
            self.assertEqual(
                (destination / "overlays/hunk/patches/0002-add.patch").read_text(),
                "add\n",
            )
            (source / "overlays/hunk/patches/not-a-patch.txt").write_text("reject\n")
            rejected_extra = subprocess.run(
                [sys.executable, script, "hunk", source, destination],
                capture_output=True,
                text=True,
            )
            self.assertEqual(rejected_extra.returncode, 1)
            self.assertIn("Invalid patch artifact:", rejected_extra.stderr)

    def test_package_layout_guard(self):
        script = ROOT / "bin/check-package-layout"
        flat_packages = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "packages").glob("*.nix"))

        current_tree = subprocess.run(
            ["bash", script, *flat_packages],
            capture_output=True,
            text=True,
        )
        self.assertEqual(current_tree.returncode, 0, current_tree.stderr)

        allowed = subprocess.run(
            ["bash", script, "packages/sem.nix", "packages/example/default.nix"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(allowed.returncode, 0, allowed.stderr)

        rejected = subprocess.run(
            ["bash", script, "packages/new-package.nix"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(rejected.returncode, 1)
        self.assertIn(
            "Package must live at packages/<name>/default.nix: packages/new-package.nix",
            rejected.stderr,
        )

    def test_renovate_config_keeps_hash_refresh_and_reduces_noise(self):
        config = json.loads((ROOT / "renovate.json").read_text())
        workflow = (ROOT / ".github/workflows/renovate.yml").read_text()
        command = "nix run --accept-flake-config .#renovate-update-nix-hashes"

        self.assertIn("config:recommended", config["extends"])
        self.assertTrue(config["nix"]["enabled"])
        self.assertTrue(config["dependencyDashboard"])
        self.assertTrue(config["lockFileMaintenance"]["enabled"])
        self.assertEqual(config["timezone"], "America/Chicago")
        self.assertEqual(config["schedule"], ["* 4-8 * * 1"])
        self.assertFalse(config["updateNotScheduled"])
        self.assertEqual(config["lockFileMaintenance"]["schedule"], config["schedule"])
        self.assertEqual(config["minimumReleaseAge"], "3 days")
        self.assertEqual(config["prHourlyLimit"], 2)
        self.assertLessEqual(config["prConcurrentLimit"], 5)
        self.assertTrue(config["dependencyDashboardApproval"])
        # Bare renovate branches do not trigger CI. Waiting for checks before
        # creating their PR would delay the event that starts those checks.
        self.assertEqual(config["prCreation"], "immediate")
        self.assertFalse(config["automerge"])
        self.assertFalse(config["platformAutomerge"])
        self.assertFalse(config["pruneStaleBranches"], "Existing PRs/branches are on hold")
        for policy in [config["lockFileMaintenance"], config["vulnerabilityAlerts"], *config["packageRules"]]:
            self.assertFalse(policy.get("automerge", False), "Use exact-SHA candidate admission")
        repair = (ROOT / ".github/workflows/renovate-patch-repair.yml").read_text()
        self.assertNotIn("gh pr merge", repair)
        self.assertIn("docs/runbooks/candidate-ci.md", repair)
        self.assertIn("main unchanged", repair)
        # Command execution is allowed by the self-hosted runner, not repo config.
        self.assertNotIn("allowedCommands", config)
        self.assertIn("RENOVATE_ALLOWED_COMMANDS", workflow)
        self.assertEqual(config["postUpgradeTasks"]["commands"], [command])
        self.assertIn("nix run --accept-flake-config", workflow)
        self.assertIn("renovate-update-nix-hashes", workflow)
        self.assertIn("accept-flake-config = true", workflow)
        hash_script = (ROOT / "flake.nix").read_text()
        self.assertIn("nix-update --flake --version=skip", hash_script)
        self.assertNotIn("nix-update --flake --version=skip --build", hash_script)

        descriptions = {manager["description"] for manager in config["customManagers"]}
        self.assertGreaterEqual(len(config["customManagers"]), 3)
        self.assertTrue(any("packages/" in description for description in descriptions))
        self.assertTrue(any("Hunk's flake input" in description for description in descriptions))

        grouped_without_name = [
            rule
            for rule in config["packageRules"]
            if rule.get("groupSlug") and "groupName" not in rule
        ]
        self.assertEqual(
            grouped_without_name,
            [],
            "groupSlug without groupName collapses unrelated PRs onto one branch",
        )

        slugs = [rule.get("groupSlug") for rule in config["packageRules"]]
        javascript = next(
            rule
            for rule in config["packageRules"]
            if rule.get("groupName") == "{{packageFileDir}} dependencies"
        )
        workspace = next(
            rule
            for rule in config["packageRules"]
            if rule.get("groupSlug") == "pi-workspace-dependencies"
        )
        self.assertNotIn("matchDepTypes", javascript, "Runtime/dev updates share locks")
        self.assertEqual(javascript["groupSlug"], javascript["groupName"])
        self.assertEqual(javascript["matchManagers"], ["npm", "bun"])
        self.assertEqual(
            javascript["matchUpdateTypes"],
            ["minor", "patch", "pin", "digest"],
        )
        self.assertEqual(workspace["matchFileNames"], ["packages/pi-packages/**"])
        self.assertGreater(config["packageRules"].index(workspace), config["packageRules"].index(javascript))
        self.assertLess(slugs.index("pi-workspace-dependencies"), slugs.index("hunk"))
        actions = next(
            rule for rule in config["packageRules"] if rule.get("groupSlug") == "github-actions"
        )
        self.assertIn("digest", actions["matchUpdateTypes"])
        hunk = next(rule for rule in config["packageRules"] if rule.get("groupSlug") == "hunk")
        self.assertFalse(hunk["automerge"])
        self.assertEqual(
            {rule["groupSlug"] for rule in config["packageRules"] if rule.get("dependencyDashboardApproval") is False},
            {"callstack-types-patches", "callstack-tsgolint-patches"},
        )
        for slug, dependency, updates, label in (
            ("callstack-types-patches", "@types/bun", ["minor", "patch"], "renovate-types-pilot"),
            ("callstack-tsgolint-patches", "oxlint-tsgolint", ["patch"], "renovate-lint-pilot"),
        ):
            with self.subTest(slug=slug):
                pilot = next(rule for rule in config["packageRules"] if rule.get("groupSlug") == slug)
                self.assertEqual(pilot["matchManagers"], ["npm"])
                self.assertEqual(pilot["matchFileNames"], ["packages/callstack-diff/package.json"])
                self.assertEqual(pilot["matchDepNames"], [dependency])
                self.assertEqual(pilot["matchDepTypes"], ["devDependencies"])
                self.assertEqual(pilot["matchUpdateTypes"], updates)
                self.assertEqual(pilot["labels"], ["dependencies", "javascript", label])
                self.assertEqual(pilot["prConcurrentLimit"], 0)
                self.assertEqual(pilot["branchConcurrentLimit"], 0)
        self.assertEqual(config["prConcurrentLimit"], 4)

        digest_rule = next(
            rule
            for rule in config["packageRules"]
            if rule.get("matchDatasources") == ["git-refs"]
            and rule.get("matchUpdateTypes") == ["digest"]
        )
        self.assertFalse(digest_rule["enabled"])

        nix_groups = [
            rule
            for rule in config["packageRules"]
            if rule.get("matchManagers") == ["nix"] and "groupName" in rule
        ]
        self.assertTrue(nix_groups)
        for rule in nix_groups:
            self.assertNotIn(
                "lockFileMaintenance",
                rule.get("matchUpdateTypes", []),
                "lockFileMaintenance must stay off grouped flake-input PRs",
            )

        majors = next(rule for rule in config["packageRules"] if rule.get("matchUpdateTypes") == ["major"])
        self.assertTrue(majors["dependencyDashboardApproval"])
        self.assertFalse(majors["automerge"])
        self.assertTrue(config["separateMajorMinor"])
        self.assertFalse(config["separateMultipleMajor"])


if __name__ == "__main__":
    unittest.main()
