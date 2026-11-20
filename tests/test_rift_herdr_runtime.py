from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_rift_is_packaged_only_for_herdr_agent_runtime() -> None:
    package = ROOT / "packages" / "rift"
    herdr_module = (ROOT / "modules" / "shell" / "herdr" / "native.nix").read_text()

    assert (package / "default.nix").is_file()
    assert (package / "package-harness.json").is_file()
    assert 'home.file.".local/bin/rift".source = lib.getExe pkgs.my.rift;' in herdr_module
    assert "pkgs.my.rift" not in (ROOT / "default.nix").read_text()


def test_herdr_tnote_is_optional() -> None:
    herdr_module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()

    assert "tnote.enable = lib.my.mkBoolOpt true;" in herdr_module
    native_module = (ROOT / "modules" / "shell" / "herdr" / "native.nix").read_text()
    assert "lib.optional cfg.tnote.enable pkgs.my.tnote" in native_module
