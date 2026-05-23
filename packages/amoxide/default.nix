{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "amoxide";
  version = "0.9.0";

  outputs = [
    "out"
    "tui"
  ];

  src = fetchFromGitHub {
    owner = "sassman";
    repo = "amoxide-rs";
    rev = "v${version}";
    hash = "sha256-LwUpoRHLqq4o6oS9TtvdwdGs2IHUcyQamTAAiiFaPD0=";
  };

  cargoHash = "sha256-Y6hBx7HjusvX7UVQZ+e95u6QHbfYXLz+onH2cwG6wIw=";

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
