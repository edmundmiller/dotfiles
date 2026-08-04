from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_meat_is_packaged_and_installed_on_mactraitorpro() -> None:
    package = (ROOT / "packages/meat/default.nix").read_text()
    host = (ROOT / "hosts/mactraitorpro/default.nix").read_text()

    assert 'pname = "meat";' in package
    assert 'rev = "f39f41dfe7b5b37a12b35fdfbaecc7e779855bd3";' in package
    assert 'subPackages = [ "cmd/meat" ];' in package
    assert "my.meat" in host
