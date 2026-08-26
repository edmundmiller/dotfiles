from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class EmacsValeTest(unittest.TestCase):
    def test_pins_native_mdx_capable_runtime(self) -> None:
        vale = (ROOT / "packages/vale/default.nix").read_text()
        vale_ls = (ROOT / "packages/vale-ls/default.nix").read_text()

        self.assertIn('version = "3.18.0";', vale)
        self.assertIn('version = "0.5.0";', vale_ls)

    def test_global_config_uses_native_prose_formats(self) -> None:
        config = (ROOT / "config/vale/.vale.ini").read_text()

        self.assertIn("[*.{md,markdown,mdx,org,txt}]", config)
        self.assertNotIn("mdx = md", config)
        self.assertNotIn("tex = md", config)

    def test_module_keeps_synced_styles_writable(self) -> None:
        module = (ROOT / "modules/editors/emacs.nix").read_text()

        self.assertIn("my.vale", module)
        self.assertIn("my.vale-ls", module)
        self.assertIn(
            'env.VALE_STYLES_PATH = "$XDG_DATA_HOME/vale/styles";', module
        )
        self.assertIn('"vale/.vale.ini"', module)
        self.assertIn('"Library/Application Support/vale/.vale.ini"', module)
        self.assertIn('"vale/styles/config/vocabularies/Base/accept.txt"', module)


if __name__ == "__main__":
    unittest.main()
