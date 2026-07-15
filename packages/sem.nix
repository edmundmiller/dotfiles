# sem.nix - Semantic git diff/graph/impact CLI packaged from Ataraxy-Labs/sem
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "sem";
  version = "0.21.0";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "sem";
    rev = "v${version}";
    hash = "sha256-3lAcIxNM/4IFSj+7rMOjXsLZiIcAC4EESJBzWYkuDK0=";
  };

  sourceRoot = "source/crates";
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  cargoBuildFlags = [
    "-p"
    "sem-cli"
    "-p"
    "sem-mcp"
  ];

  cargoInstallFlags = cargoBuildFlags;

  cargoHash = "sha256-0/nTkOrGIWDJ3b1LbcIjR4yIZ8s/e5CcbgJ4m1AfxBs=";

  # Upstream graph-accuracy tests expect local fixture repos/files.
  doCheck = false;

  meta = with lib; {
    description = "Semantic version control on top of Git";
    homepage = "https://github.com/Ataraxy-Labs/sem";
    license = with licenses; [
      mit
      asl20
    ];
    maintainers = [ ];
    mainProgram = "sem";
    platforms = platforms.unix;
  };
}
