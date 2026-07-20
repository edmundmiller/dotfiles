from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_jj_workspace_plugin_is_a_patched_local_package() -> None:
    package = ROOT / "packages" / "herdr-plugin-jj-workspace"
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()

    assert (package / "default.nix").is_file()
    assert (package / "package-harness.json").is_file()
    assert list((package / "patches").glob("*.patch"))
    assert "pkgs.my.herdr-plugin-jj-workspace" in module
    assert "install_plugin NathanFlurry herdr-plugin-jj-workspace" not in module
    assert "ensure_pinned_plugin" not in module
    assert "edmundmiller/herdr-plugin-jj-workspace" not in module
