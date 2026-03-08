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
  version = "0.3.5";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "sem";
    rev = "v${version}";
    hash = "sha256-G/EtpFnz8VJi2ln5QevFwxudVEmLLv80uDTiA7T6C+A=";
  };

  sourceRoot = "source/crates";
  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail 'members = ["sem-core", "sem-cli", "sem-api"]' 'members = ["sem-core", "sem-cli"]'
  '';
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  cargoBuildFlags = [
    "-p"
    "sem-cli"
  ];
  cargoHash = "sha256-zpQrl3r95hjDcrj+0oa7/v1vVEra0P6Hf9CB5pkBzy8=";

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
