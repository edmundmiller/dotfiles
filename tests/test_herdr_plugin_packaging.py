import re
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


def test_vercel_sandbox_plugin_is_mtp_scoped_and_agent_selectable() -> None:
    package = ROOT / "packages" / "herdr-vercel-sandbox-plugin"
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()
    host = (ROOT / "hosts" / "mactraitorpro" / "default.nix").read_text()

    assert (package / "default.nix").is_file()
    assert (package / "package-harness.json").is_file()
    assert list((package / "patches").glob("*.patch"))
    assert "pkgs.my.herdr-vercel-sandbox-plugin" in module
    assert "vercelSandbox.enable" in module
    assert "install_plugin vercel-labs herdr-vercel-sandbox-plugin" not in module
    assert '"agentKind": "omp"' in module
    assert '"allowCandidateAgents": true' in module
    assert '"omp"' in module
    assert '"opencode-v2"' in module
    assert '"17.2.12"' in module
    assert '"0.0.0-beta-202608091410"' in module
    assert 'command = "vercel.sandbox.start-codex"' in module
    assert 'command = "vercel.sandbox.start-omp"' in module
    assert 'command = "vercel.sandbox.start-opencode-v2"' in module
    assert re.search(
        r"key = \"prefix\+S\".*?command = \"vercel\.sandbox\.start-omp\"",
        module,
        re.DOTALL,
    )
    assert re.search(
        r"key = \"prefix\+alt\+c\".*?command = \"vercel\.sandbox\.start-codex\"",
        module,
        re.DOTALL,
    )
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
    assert 'command = "tab-smart-rename.rename-now"' not in module


def test_auto_title_hook_is_pinned_and_installed_for_codex_and_claude() -> None:
    package = ROOT / "packages" / "herdr-auto-title" / "default.nix"
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()

    expression = package.read_text()
    assert 'owner = "sh1ma";' in expression
    assert 'repo = "herdr-auto-title";' in expression
    assert 'rev = "aae70057b0c48b9d80aaecca77079879ce01f694";' in expression
    assert "herdr_auto_title.py" in expression
    assert "pkgs.my.herdr-auto-title" in module
    assert "home.activation.herdr-auto-title" in module
    assert 'entryAfter [ "herdr-agent-integrations" ]' in module
    assert "--claude" in module
    assert "--codex" in module


def test_smart_rename_binding_is_cleaned_before_reapplying_canonical_config() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()

    assert 'command["command"]' in module
    assert "for command in canonical_commands" in module


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
    assert 'managed_section("experimental")' in module
    assert "official.browser" not in module


def test_terminal_chrome_is_minimal_and_activation_managed() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()
    config = tomllib.loads((ROOT / "config" / "herdr" / "config.toml").read_text())

    assert config["ui"]["pane_scrollbars"] is False
    assert config["ui"]["pane_gaps"] is False
    assert 'managed_section("ui")' in module
    assert '"pane_scrollbars": "false"' not in module
    assert '"pane_gaps": "false"' not in module


def test_native_session_context_replaces_window_title_plugin() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()
    config = tomllib.loads((ROOT / "config" / "herdr" / "config.toml").read_text())

    assert config["keys"]["prefix"] == "ctrl+space"
    assert "herdrConfigTemplate = cfg.configFile;" in module
    assert 'prefix = "ctrl+space"' not in module
    assert "prefix = mkOpt" not in module
    assert 'managed_keys["prefix"]' not in module
    assert config["ui"]["pane_outer_borders"] is False
    assert config["ui"]["tab_bar_right"] == [
        {"type": "zoom"},
        {"type": "hostname"},
    ]
    assert config["ui"]["window_title"] == "{hostname}: {workspace}"
    assert '"pane_outer_borders": "false"' not in module
    assert '"tab_bar_right": \'[{ type = "zoom" }, { type = "hostname" }]\'' not in module
    assert '"window_title": \'"{hostname}: {workspace}"\'' not in module
    assert "install_plugin rjyo herdr-window-title-sync" not in module
    assert "uninstall_plugin rjyo.window-title-sync" in module


def test_writable_config_reads_managed_values_from_tracked_template() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()
    activation = module.split("home.activation.herdr-config-bootstrap", 1)[1]

    assert "canonical_config = tomllib.loads(template_path.read_text())" in activation
    assert 'canonical_keys = canonical_config.get("keys", {})' in activation
    assert 'canonical_commands = canonical_keys.get("command", [])' in activation
    assert 'managed_section("session")' in activation
    assert 'managed_section("experimental")' in activation
    assert 'managed_section("ui")' in activation
    assert '"settings": "prefix+comma"' not in activation
    assert '"agent_panel_sort": \'"priority"\'' not in activation


def test_omp_integration_install_isolates_pi_agent_dir() -> None:
    module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()

    # Herdr 0.8 refuses to install OMP when Pi and OMP resolve to the same
    # extension directory. Activation can inherit PI_CODING_AGENT_DIR from a
    # wrapped OMP, so the OMP install must clear it and rely on PI_CONFIG_DIR.
    assert "PI_CODING_AGENT_DIR= PI_CONFIG_DIR=.omp install_integration omp" in module
    assert 'PI_CODING_AGENT_DIR="$HOME/.omp/agent" install_integration omp' not in module
    # Pi keeps its own absolute override, which wins over any ambient value.
    assert 'PI_CODING_AGENT_DIR="$HOME/.pi/agent" install_integration pi' in module
