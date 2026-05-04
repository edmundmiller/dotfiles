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
  version = "0.3.2";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "weave";
    rev = "v${version}";
    hash = "sha256-NlBHoxDgiNF38ktx2d44BmdABrPh4wr52mkNjlAmtX0=";
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

  cargoHash = "sha256-XUasm/j9FOH9vDqSt1mYBfk3Y9UFKyFb8EKovptXYbI=";

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
