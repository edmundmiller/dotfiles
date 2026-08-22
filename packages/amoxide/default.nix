{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "amoxide";
  version = "0.10.6";

  outputs = [
    "out"
    "tui"
  ];

  src = fetchFromGitHub {
    owner = "sassman";
    repo = "amoxide-rs";
    rev = "v${version}";
    hash = "sha256-jX30GomQZlwmx5hCkvOFQux7EVvLMyHtUQL79tFmsgA=";
  };

  cargoHash = "sha256-HlVtBAdj6spo6XTHrNnHWRbSebVNmN6UhEAQZWxRb1g=";

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
