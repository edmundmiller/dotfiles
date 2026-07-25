{
  cacert,
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "buzz";
  version = "0.4.26";

  src = fetchFromGitHub {
    owner = "block";
    repo = "buzz";
    rev = "v${version}";
    hash = "sha256-4WnTDKw00r1AOsaaAFB/NFPYI0XTB0totLY8shEE+O0=";
  };

  cargoHash = "sha256-rZmZrgbZ2+oWZOzhF3Iq1W5Jev5kYBvT2f0iR+IdiKc=";
  patches = [ ./patches/exact-respond-to-allowlist.patch ];

  cargoBuildFlags = [
    "--package=buzz-acp"
    "--package=buzz-cli"
  ];
  cargoInstallFlags = cargoBuildFlags;
  cargoTestFlags = [
    "--package=buzz-acp"
    "author_gate_tests"
  ];
  preCheck = ''
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
  '';

  meta = {
    description = "Buzz ACP harness and command-line client";
    homepage = "https://github.com/block/buzz";
    license = lib.licenses.asl20;
    mainProgram = "buzz-acp";
    platforms = lib.platforms.unix;
  };
}
