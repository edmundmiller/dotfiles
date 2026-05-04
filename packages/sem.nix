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
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "sem";
    rev = "v${version}";
    hash = "sha256-UjBjkscHwyry+qbfgJp4M+ftc+WAUsJljl3MxHWCQho=";
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

  cargoHash = "sha256-aQ31vUJ4U2c4IfXU2aA8HRfUl/wNgbH/5YN/xzAcP7E=";

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
