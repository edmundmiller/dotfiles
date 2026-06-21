{
  lib,
  rustPlatform,
  fetchurl,
}:

rustPlatform.buildRustPackage {
  pname = "jj-vine";
  version = "0.5.3";

  src = fetchurl {
    url = "https://codeberg.org/abrenneke/jj-vine/archive/v0.5.3.tar.gz";
    hash = "sha256-r1HwSWOf/AqalrY6NGKU2/0W6Y21L3gNfEQjdO+kzWY=";
  };

  cargoHash = "sha256-nuj0cugeK5oc+sZmm1f5dvGEjML0qkle5uO66e54VIY=";

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
