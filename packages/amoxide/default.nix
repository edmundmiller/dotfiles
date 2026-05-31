{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "amoxide";
  version = "0.9.1";

  outputs = [
    "out"
    "tui"
  ];

  src = fetchFromGitHub {
    owner = "sassman";
    repo = "amoxide-rs";
    rev = "v${version}";
    hash = "sha256-74uE5vFJbgF2adh5EqBOLv1/tHkkUpDTAmnmgE7WCCQ=";
  };

  cargoHash = "sha256-ONQ4idyZ87OWjFSiSKQZBWg/nvRUwUqr86mlu07AXHI=";

  doCheck = false;

  postInstall = ''
    mkdir -p $tui/bin
    mv $out/bin/am-tui $tui/bin/am-tui
  '';

  meta = with lib; {
    description = "Context-aware shell alias manager";
    homepage = "https://amoxide.rs/";
    license = licenses.gpl3Only;
    maintainers = [ ];
    platforms = platforms.unix;
    mainProgram = "am";
  };
}
