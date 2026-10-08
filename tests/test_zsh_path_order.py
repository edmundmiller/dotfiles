"""Interactive startup must not select unmanaged Codex over Nix Codex."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("zsh"), "requires zsh")
class ZshPathOrderTests(unittest.TestCase):
    def test_interactive_startup_restores_managed_codex(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            zdotdir = home / "zsh"
            cache = home / "cache"
            zdotdir.mkdir()
            cache.mkdir()
            (zdotdir / "config.zsh").touch()
            (zdotdir / "path.zsh").symlink_to(ROOT / "config/zsh/path.zsh")
            (cache / ".zsh_plugins.zsh").touch()
            for name in (".nix-profile/bin", "unmanaged/bin"):
                bindir = home / name
                bindir.mkdir(parents=True)
                executable = bindir / "codex"
                executable.write_text("#!/bin/sh\nexit 0\n")
                executable.chmod(0o755)

            result = subprocess.run(
                [
                    "zsh", "-dfc",
                    'source "$ZSHRC_FILE"; whence -p codex',
                ],
                env={
                    **os.environ,
                    "HOME": str(home),
                    "USER": "zsh-path-test-user",
                    "ZDOTDIR": str(zdotdir),
                    "XDG_CONFIG_HOME": str(home),
                    "XDG_DATA_HOME": str(home / "data"),
                    "XDG_CACHE_HOME": str(cache),
                    "ZSH_CACHE": str(cache),
                    "ZSHRC_FILE": str(ROOT / "config/zsh/.zshrc"),
                    "TERM": "dumb",
                    # Model brew shellenv prepending its bin after .zshenv.
                    "PATH": f"{home}/unmanaged/bin:{home}/.nix-profile/bin:/usr/bin:/bin",
                },
                capture_output=True, text=True, check=True,
            )
            self.assertEqual(result.stdout.strip(), str(home / ".nix-profile/bin/codex"))
