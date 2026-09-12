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


def test_herdr_vm_test_does_not_evaluate_private_tnote() -> None:
    herdr_module = (ROOT / "modules" / "shell" / "herdr" / "default.nix").read_text()
    vm_test = (ROOT / "modules" / "shell" / "herdr" / "_tests" / "vm-test.nix").read_text()

    assert "tnote.enable = mkBoolOpt true;" in herdr_module
    assert 'optional cfg.tnote.enable "${pkgs.my.tnote}/bin"' in herdr_module
    assert "herdrPackages ++ optional cfg.tnote.enable pkgs.my.tnote" in herdr_module
    assert "modules.shell.herdr.tnote.enable = false;" in vm_test
