{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "gxf2bed";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "alejandrogzi";
    repo = "gxf2bed";
    rev = "v${version}";
    hash = "sha256-7EFmaX1axQ574N3vg+hma4F832oHxlFf2bshEsNoDUM=";
  };

  cargoHash = "sha256-KPD5UTM9QFeC2rZ+oF2Mv5Ar7c5VlEZ/mwKiSoV1s+o=";

  meta = with lib; {
    description = "Fastest GTF/GFF-to-BED converter chilling around";
    homepage = "https://github.com/alejandrogzi/gxf2bed";
    license = licenses.mit;
    mainProgram = "gxf2bed";
  };
}
