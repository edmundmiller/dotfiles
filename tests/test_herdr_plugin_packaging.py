import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_worktree_events_supersede_legacy_post_create_command() -> None:
    plugin = ROOT / "packages" / "herdr-plugins" / "dotfiles-dev-layout"
    manifest = tomllib.loads((plugin / "herdr-plugin.toml").read_text())
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()
    config = tomllib.loads((ROOT / "config" / "herdr" / "config.toml").read_text())

    assert {event["on"] for event in manifest["events"]} == {
        "workspace.created",
        "worktree.created",
    }
    assert "post_create_command" not in config.get("worktrees", {})
    assert 'if key == "post_create_command":' in module


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


def test_local_plugin_link_defers_unavailable_runtime() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()

    assert "link_output=" in module
    assert "Connection refused" in module
    assert "protocol_mismatch" in module
    assert "deferring local plugin link" in module


def test_marketplace_activation_defers_protocol_mismatch() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()

    assert 'installed_json=$("$herdr_cmd" plugin list --json 2>&1)' in module
    assert "protocol_mismatch" in module
    assert "deferring marketplace plugin installation" in module


def test_vercel_sandbox_plugin_is_mtp_scoped_and_codex_configured() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()
    host = (ROOT / "hosts" / "mactraitorpro" / "default.nix").read_text()

    assert "vercelSandbox.enable" in module
    assert "install_plugin vercel-labs herdr-vercel-sandbox-plugin" in module
    assert '"agentKind": "codex"' in module
    assert 'command = "vercel.sandbox.start-agent"' in module
    assert 'command = "vercel.sandbox.apply-changes"' in module
    assert "herdr.vercelSandbox.enable = true;" in host
    assert '"vercel@58.9.0"' in host


def test_smart_rename_is_packaged_started_and_bound() -> None:
    package = ROOT / "packages" / "herdr-tab-smart-rename"
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()
    config = tomllib.loads((ROOT / "config" / "herdr" / "config.toml").read_text())
    commands = config["keys"]["command"]

    assert (package / "default.nix").is_file()
    assert (package / "package-harness.json").is_file()
    assert len(list((package / "patches").glob("*.patch"))) == 2
    assert "pkgs.my.herdr-tab-smart-rename" in module
    assert "install_plugin iurysza herdr-tab-smart-rename" not in module
    assert "home.activation.herdr-smart-rename" in module
    assert 'entryAfter [ "herdr-plugin-registry" ]' in module
    assert "plugin action invoke start --plugin tab-smart-rename" in module
    assert "deferring smart rename worker start" in module
    assert {
        "key": "prefix+t",
        "type": "plugin_action",
        "command": "tab-smart-rename.rename-now",
        "description": "smart rename current tab",
    } in commands
    assert 'command = "tab-smart-rename.rename-now"' in module


def test_smart_rename_binding_is_cleaned_before_reapplying_canonical_config() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()

    assert '"tab-smart-rename.rename-now",' in module


def test_browser_plugin_is_installed_with_graphics_and_binding() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()
    config = tomllib.loads((ROOT / "config" / "herdr" / "config.toml").read_text())

    assert config["experimental"]["kitty_graphics"] is True
    assert "install_plugin ogulcancelik herdr-browser" in module
    assert {
        "key": "prefix+B",
        "type": "shell",
        "command": (
            "${HERDR_BIN_PATH} plugin pane open --plugin official.browser "
            "--entrypoint browser --placement split --direction right --focus"
        ),
        "description": "open browser in a right split",
    } in config["keys"]["command"]
    assert '"kitty_graphics": "true"' in module
    assert "official.browser" in module


def test_omp_integration_install_isolates_pi_agent_dir() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()

    # Herdr 0.8 refuses to install OMP when Pi and OMP resolve to the same
    # extension directory. Activation can inherit PI_CODING_AGENT_DIR from a
    # wrapped OMP, so the OMP install must clear it and rely on PI_CONFIG_DIR.
    assert "PI_CODING_AGENT_DIR= PI_CONFIG_DIR=.omp install_integration omp" in module
    assert 'PI_CODING_AGENT_DIR="$HOME/.omp/agent" install_integration omp' not in module
    # Pi keeps its own absolute override, which wins over any ambient value.
    assert 'PI_CODING_AGENT_DIR="$HOME/.pi/agent" install_integration pi' in module
