{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "leaf";
  version = "1.25.0";

  src = fetchFromGitHub {
    owner = "rivolink";
    repo = "leaf";
    rev = version;
    hash = "sha256-OSx797tkwjKU9j+0AhQIT7uLM75PzHVw12d5LG6vT3Q=";
  };

  cargoHash = "sha256-rEISBL5vWYP5UKFKWLA2RxlqDBFTz8qPpiPOfxeNUFQ=";

  meta = {
    description = "Friendly terminal Markdown previewer";
    homepage = "https://github.com/rivolink/leaf";
    license = lib.licenses.mit;
    mainProgram = "leaf";
    platforms = lib.platforms.unix;
  };
}
