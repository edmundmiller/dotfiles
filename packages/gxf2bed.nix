{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "gxf2bed";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "alejandrogzi";
    repo = "gxf2bed";
    rev = "v${version}";
    hash = "sha256-C88zPTUF9rHQ+susq6CPK16bGs6GAFH4QI/whkjuIKQ=";
  };

  cargoHash = "sha256-zsbm1wZI199G++wzy0sagDh7jNZIYxa8HmzaFNej9Q4=";

  meta = with lib; {
    description = "Fastest GTF/GFF-to-BED converter chilling around";
    homepage = "https://github.com/alejandrogzi/gxf2bed";
    license = licenses.mit;
    mainProgram = "gxf2bed";
  };
}
