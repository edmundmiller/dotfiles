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
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "inspect";
    rev = "v${version}";
    hash = "sha256-pGcE9fnJzgdD38/erHjqHVoBQfGEKxgyN3goUxFFsec=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  postPatch = ''
    cp ${./inspect.Cargo.lock} Cargo.lock
  '';

  cargoBuildFlags = [
    "-p"
    "inspect-cli"
  ];

  cargoLock = {
    lockFile = ./inspect.Cargo.lock;
    allowBuiltinFetchGit = true;
  };

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
