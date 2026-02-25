{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage {
  pname = "jj-vine";
  version = "0.3.6";

  src = fetchFromGitHub {
    owner = "abrenneke";
    repo = "jj-vine";
    rev = "v0.3.6";
    hash = "sha256-vvNbeQvP205snAGiql/i8yFGyMw23YkSU4/uxOSnycY=";
  };

  cargoHash = "sha256-vcpaKlNeORnDpVqXxu0TrXWaWNfaK9QPVJOrty9WmcQ=";

  # Integration tests need network/forge access
  doCheck = false;

  meta = with lib; {
    description = "Stacked pull requests for jj (jujutsu) — bookmark-based, multi-forge";
    homepage = "https://codeberg.org/abrenneke/jj-vine";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "jj-vine";
    platforms = platforms.unix;
  };
}
