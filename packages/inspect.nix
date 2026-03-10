# inspect.nix - Entity-level code review CLI packaged from Ataraxy-Labs/inspect
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "inspect";
  version = "unstable-2026-03-10";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "inspect";
    rev = "65baa7d1ca7180b3c3e2b102649388c867da96d9";
    hash = "sha256-kuwzx/UcA4hpw+5ntKBLMMshXeDirx/g3GlN0oYwEUA=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  cargoBuildFlags = [
    "-p"
    "inspect-cli"
  ];
  cargoHash = "sha256-aUH+ODypabS+eSj2QRORQdgP+SKz2QenjNQdXiOPyO0=";

  # Upstream tests expect local fixture paths unavailable in nix sandbox.
  doCheck = false;

  meta = with lib; {
    description = "Entity-level code review for Git";
    homepage = "https://github.com/Ataraxy-Labs/inspect";
    license = licenses.unfree;
    maintainers = [ ];
    mainProgram = "inspect";
    platforms = platforms.unix;
  };
}
