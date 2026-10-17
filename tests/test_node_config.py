import io
import json
import os
import shutil
import subprocess
import tarfile
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def nix_path() -> str:
    # Prefer the system-managed nix: older profile/PATH versions ignore the
    # flake's nixConfig as untrusted and fail on dynamic-derivations.
    system_nix = Path("/run/current-system/sw/bin/nix")
    if system_nix.is_file():
        return str(system_nix)
    profile_nix = Path("/nix/var/nix/profiles/default/bin/nix")
    if profile_nix.is_file():
        return str(profile_nix)
    return shutil.which("nix") or "nix"


class NodeConfigTests(unittest.TestCase):
    def test_darwin_skips_bun_activation_and_removes_legacy_links(self) -> None:
        result = subprocess.run(
            [
                nix_path(),
                "eval",
                "--json",
                f"{ROOT}#darwinConfigurations",
                "--no-write-lock-file",
                "--apply",
                """
                configs: builtins.mapAttrs (_: cfg: {
                  activation = cfg.config.system.activationScripts.extraActivation.text or "";
                  globals = cfg.config.modules.dev.node.bunGlobalPackages;
                  cleanup = cfg.config.home-manager.users.${cfg.config.user.name}
                    .home.activation.removeLegacyBunClis.data;
                }) configs
                """,
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

        for host, config in json.loads(result.stdout).items():
            with self.subTest(host=host):
                self.assertEqual(config["globals"], [])
                self.assertNotIn("ensure-globals.js", config["activation"])
                commands = ["excalidraw"]
                if host == "MacTraitor-Pro":
                    commands += ["critique", "vercel", "vc"]

                with tempfile.TemporaryDirectory() as temp_dir:
                    home = Path(temp_dir)
                    bins = home / ".bun/bin"
                    bins.mkdir(parents=True)
                    env = {**os.environ, "HOME": str(home)}

                    def cleanup():
                        subprocess.run(["bash", "-eu", "-c", config["cleanup"]], env=env, check=True)

                    for prefix in ("../install/global/node_modules", str(home / ".bun/install/global/node_modules")):
                        for command in commands:
                            (bins / command).symlink_to(f"{prefix}/{command}/cli.js")
                        cleanup()
                        for command in commands:
                            self.assertFalse((bins / command).is_symlink())
                    cleanup()  # Repeated activation is harmless.

                    for command in commands:
                        (bins / command).write_text("user script")
                    cleanup()
                    for command in commands:
                        self.assertEqual((bins / command).read_text(), "user script")
                        (bins / command).unlink()
                        (bins / command).symlink_to("/custom/cli")
                    cleanup()
                    for command in commands:
                        self.assertEqual(os.readlink(bins / command), "/custom/cli")

    def test_bun_global_install_skips_unchanged_and_repairs_drift(self) -> None:
        bun = shutil.which("bun")
        if bun is None:
            self.skipTest("bun is not available")

        requests = []
        name = "@activation-test/cli"
        archives = {}
        for version in ("1.0.0", "1.0.1"):
            buffer = io.BytesIO()
            with tarfile.open(fileobj=buffer, mode="w:gz") as archive:
                files = {
                    "package.json": json.dumps({"name": name, "version": version, "bin": "cli.js"}),
                    "cli.js": f'#!/usr/bin/env bun\nconsole.log("{version}");\n',
                }
                for path, contents in files.items():
                    data = contents.encode()
                    info = tarfile.TarInfo(f"package/{path}")
                    info.size = len(data)
                    info.mode = 0o755
                    archive.addfile(info, io.BytesIO(data))
            archives[version] = buffer.getvalue()

        class Registry(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                requests.append(self.path)
                if self.path.endswith(".tgz"):
                    body = archives[self.path.removeprefix("/").removesuffix(".tgz")]
                else:
                    base = f"http://127.0.0.1:{self.server.server_port}"
                    body = json.dumps({"name": name, "versions": {
                        version: {"name": name, "version": version, "bin": "cli.js",
                                  "dist": {"tarball": f"{base}/{version}.tgz"}}
                        for version in archives
                    }}).encode()
                self.send_response(200)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

        server = ThreadingHTTPServer(("127.0.0.1", 0), Registry)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)

        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            env = {
                "HOME": str(temp / "home"),
                "BUN_INSTALL": str(temp / "bun"),
                "PATH": os.environ["PATH"],
                "npm_config_registry": f"http://127.0.0.1:{server.server_port}",
            }
            (temp / "home").mkdir()
            command = [bun, str(ROOT / "config/bun/ensure-globals.js")]
            binary = temp / "bun/bin/cli"

            def ensure(version):
                result = subprocess.run(command + [f"{name}@{version}"], capture_output=True,
                                        text=True, env=env, timeout=30, check=False)
                self.assertEqual(result.returncode, 0, result.stderr)
                output = subprocess.check_output([str(binary)], env=env, text=True)
                self.assertEqual(output.strip(), version)

            ensure("1.0.0")
            request_count = len(requests)
            self.assertGreater(request_count, 0)
            modified = binary.stat().st_mtime_ns
            ensure("1.0.0")
            self.assertEqual(len(requests), request_count, "unchanged install accessed registry")
            self.assertEqual(binary.stat().st_mtime_ns, modified)
            ensure("1.0.1")
            binary.unlink()
            ensure("1.0.1")
            binary.unlink()
            wrong = temp / "wrong.js"
            wrong.write_text('#!/usr/bin/env bun\nconsole.log("wrong");\n')
            wrong.chmod(0o755)
            binary.symlink_to(wrong)
            ensure("1.0.1")

    def test_bun_global_install_reports_real_failure(self) -> None:
        bun = shutil.which("bun")
        if bun is None:
            self.skipTest("bun is not available")

        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            env = {
                "HOME": str(temp / "home"),
                "BUN_INSTALL": str(temp / "bun"),
                "PATH": str(temp / "bun" / "bin"),
            }
            (temp / "home").mkdir()
            result = subprocess.run(
                [bun, str(ROOT / "config/bun/ensure-globals.js"), str(temp / "missing-package")],
                capture_output=True,
                text=True,
                env=env,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0)

    def test_darwin_node_config_is_nvm_compatible(self) -> None:
        result = subprocess.run(
            [
                nix_path(),
                "eval",
                "--json",
                f"{ROOT}#darwinConfigurations",
                "--no-write-lock-file",
                "--apply",
                """
                configs: builtins.mapAttrs (_: cfg: {
                  hasPrefixEnv = cfg.config.env ? NPM_CONFIG_PREFIX;
                  npmConfig = cfg.config.home.configFile."npm/config".text or "";
                  zshEnvInit = cfg.config.modules.shell.zsh.envInit or "";
                }) configs
                """,
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

        for host, config in json.loads(result.stdout).items():
            with self.subTest(host=host):
                self.assertFalse(config["hasPrefixEnv"])
                self.assertNotRegex(config["npmConfig"], r"(?m)^\s*(prefix|globalconfig)\s*=")
                self.assertIn("unset NPM_CONFIG_PREFIX npm_config_prefix", config["zshEnvInit"])


if __name__ == "__main__":
    unittest.main()
