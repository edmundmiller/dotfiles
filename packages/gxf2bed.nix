{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "gxf2bed";
  version = "0.3.3";

  src = fetchFromGitHub {
    owner = "alejandrogzi";
    repo = "gxf2bed";
    rev = "v${version}";
    hash = "sha256-ALBw5L3JDzTRcDReLUKxdPm2AeBR3KJB2dP185xMXAc=";
  };

  cargoHash = "sha256-kALugtr6TXcYUZBTYadj1UEWbOpPT6s2VBpAh/G08ps=";

  meta = with lib; {
    description = "Fastest GTF/GFF-to-BED converter chilling around";
    homepage = "https://github.com/alejandrogzi/gxf2bed";
    license = licenses.mit;
    mainProgram = "gxf2bed";
  };
}
