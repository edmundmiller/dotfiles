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
  version = "0.3.6";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "weave";
    rev = "v${version}";
    hash = "sha256-VlJUXAXlWpFGlJgAEhhdeX35AZV/G/IJlXEjU/7SfJg=";
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
    "-p"
    "weave-github"
  ];

  cargoInstallFlags = cargoBuildFlags;

  cargoHash = "sha256-ZPe9l3S88idwYrayT5mmagW/VdA0VlUHTDXVyHoOF1w=";

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
