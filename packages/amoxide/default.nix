{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "amoxide";
  version = "0.10.2";

  outputs = [
    "out"
    "tui"
  ];

  src = fetchFromGitHub {
    owner = "sassman";
    repo = "amoxide-rs";
    rev = "v${version}";
    hash = "sha256-LaYAVdSTDDtjDh+GGWivZQCWrotJUizAPpGIAnKXWAY=";
  };

  cargoHash = "sha256-ZNdfzXP/0aU/kam4fAc6NvcEzq4/MSZTnfMDRcT5+Mo=";

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
