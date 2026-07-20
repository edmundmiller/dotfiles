import tomllib
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


def test_jj_workspace_fixture_uses_packaged_mkdir() -> None:
    package = ROOT / "packages" / "herdr-plugin-jj-workspace"
    expression = (package / "default.nix").read_text()

    assert "substituteInPlace src/main.rs" in expression
    assert '${lib.getExe\' coreutils "mkdir"}' in expression


def test_local_plugin_link_defers_only_connection_refusal() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()

    assert "link_output=" in module
    assert "Connection refused" in module
    assert "deferring local plugin link" in module


def test_smart_rename_is_installed_and_bound() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()
    config = tomllib.loads((ROOT / "config" / "herdr" / "config.toml").read_text())
    commands = config["keys"]["command"]

    assert "install_plugin iurysza herdr-tab-smart-rename" in module
    assert {
        "key": "prefix+t",
        "type": "plugin_action",
        "command": "tab-smart-rename.rename-now",
        "description": "smart rename current tab",
    } in commands
    assert 'command = "tab-smart-rename.rename-now"' in module
