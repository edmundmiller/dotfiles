# weave.nix - Entity-level semantic merge tooling from Ataraxy-Labs/weave
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "weave";
  version = "0.2.8";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "weave";
    rev = "v${version}";
    hash = "sha256-A9beYK1i52ghb4QQJLp5hw1DeIIc1AiK72oW5D3u08E=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  cargoBuildFlags = [
    "-p"
    "weave-cli"
    "-p"
    "weave-driver"
    "-p"
    "weave-mcp"
  ];

  cargoInstallFlags = [
    "-p"
    "weave-cli"
    "-p"
    "weave-driver"
    "-p"
    "weave-mcp"
  ];

  cargoHash = "sha256-C7vJQZ15TE9XwVLi1uCjYdQPr3TDPVEQfOVENeKXg14=";

  # Upstream has integration tests that expect git fixture repos.
  doCheck = false;

  meta = with lib; {
    description = "Entity-level semantic merge for Git";
    homepage = "https://github.com/Ataraxy-Labs/weave";
    license = with licenses; [
      mit
      asl20
    ];
    maintainers = [ ];
    mainProgram = "weave";
    platforms = platforms.unix;
  };
}
