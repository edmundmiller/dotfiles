from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_rift_is_packaged_only_for_herdr_agent_runtime() -> None:
    package = ROOT / "packages" / "rift"
    herdr_module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()

    assert (package / "default.nix").is_file()
    assert (package / "package-harness.json").is_file()
    assert '"${pkgs.my.rift}/bin"' in herdr_module
    assert 'home.file.".local/bin/rift".source = lib.getExe pkgs.my.rift;' in herdr_module
    assert "pkgs.my.rift" not in (ROOT / "default.nix").read_text()
