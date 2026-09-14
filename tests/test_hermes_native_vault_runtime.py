"""Exercise native vault storage and Nix worker compatibility with disposable data."""

import ast
from contextvars import ContextVar
import json
import os
from pathlib import Path
import sys
import tempfile
from threading import current_thread, local
import unittest


HERMES_SOURCE = os.environ.get("HERMES_SOURCE")
if HERMES_SOURCE:
    sys.path.insert(0, HERMES_SOURCE)
    from agent.vault_store import VaultError, VaultStore
    from tools.daemon_pool import DaemonThreadPoolExecutor


@unittest.skipUnless(HERMES_SOURCE, "run against the Hermes package source")
class NativeVaultRuntimeTest(unittest.TestCase):
    def test_encrypted_roundtrip_metadata_and_profile_isolation(self):
        with tempfile.TemporaryDirectory() as directory:
            first_home = Path(directory) / "first"
            second_home = Path(directory) / "second"
            first = VaultStore(first_home)
            meta = first.add_item(
                kind="login",
                label="Disposable build test",
                origin="https://EXAMPLE.org:443/login",
                secret={
                    "identifier_type": "username",
                    "identifier": "build-test",
                    "password": "disposable-vault-test-password",
                },
            )
            reopened = VaultStore(first_home)
            self.assertEqual(reopened.get_meta(meta.id).origin, "https://example.org")
            self.assertEqual(
                reopened.resolve_secret(meta.id),
                {"password": "disposable-vault-test-password"},
            )
            self.assertNotIn(
                "disposable-vault-test-password",
                json.dumps([item.to_dict() for item in reopened.list_items()]),
            )
            self.assertNotIn(
                b"disposable-vault-test-password",
                (first_home / "vault.json.enc").read_bytes(),
            )
            self.assertEqual((first_home / "vault.key").stat().st_mode & 0o777, 0o600)
            self.assertEqual(VaultStore(second_home).list_items(), [])
            with self.assertRaises(VaultError):
                VaultStore(second_home).resolve_secret(meta.id)
            self.assertTrue(reopened.remove_item(meta.id))
            self.assertEqual(VaultStore(first_home).list_items(), [])

    def test_worker_initialization_and_profile_context_do_not_leak(self):
        profile = ContextVar("profile", default="default")
        state = local()

        def initialize(value):
            state.value = value

        def observe():
            return profile.get(), state.value, current_thread().daemon

        with DaemonThreadPoolExecutor(
            max_workers=1, initializer=initialize, initargs=(41,)
        ) as pool:
            token = profile.set("scintillate")
            try:
                self.assertEqual(
                    pool.submit(observe).result(timeout=3), ("scintillate", 41, True)
                )
                profile.set("finn")
                self.assertEqual(
                    pool.submit(observe).result(timeout=3), ("finn", 41, True)
                )
            finally:
                profile.reset(token)

    def test_packaged_vault_rpc_registration(self):
        # Registration names are the client protocol, independent of handler implementation.
        source = Path(os.environ["HERMES_SOURCE"]) / "tui_gateway/methods_vault.py"
        tree = ast.parse(source.read_text())
        names = {
            decorator.args[0].value
            for node in tree.body
            if isinstance(node, ast.FunctionDef)
            for decorator in node.decorator_list
            if isinstance(decorator, ast.Call)
            and isinstance(decorator.func, ast.Name)
            and decorator.func.id == "method"
        }
        self.assertTrue(
            {
                "vault.list",
                "vault.add",
                "vault.remove",
                "vault.sources",
                "vault.source.set",
                "vault.unlock",
                "vault.lock",
            }
            <= names
        )


if __name__ == "__main__":
    unittest.main()
