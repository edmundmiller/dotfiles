from pathlib import Path
import tomllib


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules" / "shell" / "cliamp" / "default.nix"
CONFIG = ROOT / "config" / "cliamp" / "config.toml"


def test_cliamp_module_bootstraps_writable_live_config() -> None:
    module = MODULE.read_text()
    config = tomllib.loads(CONFIG.read_text())

    assert config == {"speed": 1.25, "theme": ""}
    assert "user.packages = [ cfg.package ];" in module
    assert 'if [ ! -e "$config_target" ]; then' in module
    assert 'home.configFile."cliamp/config.toml"' not in module


def test_nightrider_is_fetched_and_trusted_without_vendoring_source() -> None:
    module = MODULE.read_text()

    assert "HANCORE-linux/cliamp-plugin-nightrider" in module
    assert "d8d338fc56c4676edacf0d396b627d99bbc941ed" in module
    assert 'plugins["nightrider"] = digest' in module
    assert 'plugins["nightrider.lua"] = digest' in module
    assert not (ROOT / "config" / "cliamp" / "plugins").exists()


def test_cliamp_is_enabled_on_interactive_nix_hosts() -> None:
    for host in ("mactraitorpro", "seqeratop"):
        host_config = (ROOT / "hosts" / host / "default.nix").read_text()
        assert "cliamp.enable = true;" in host_config
