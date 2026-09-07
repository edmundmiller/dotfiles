{
  lib,
  unstable,
}:

# Exo requires Rust 1.95; the main nixpkgs pin predates that toolchain.
unstable.rustPlatform.buildRustPackage {
  pname = "exoharness-exo";
  version = "0.1.0-unstable-2026-09-06";

  src = unstable.fetchFromGitHub {
    owner = "exoharness";
    repo = "exo";
    rev = "29ebbcd959c27b3cf2539ba80e8cf912f0a5d3fb";
    hash = "sha256-qgrNK614ZC1l3mo+0zfFAo704WT285KWG8sF3Tj6kzk=";
  };

  patches = [
    ./patches/0001-chatgpt-subscription.patch
    ./patches/0002-harden-subscription-runtime.patch
  ];

  cargoHash = "sha256-GAXfXBJ9zA+zUCZeDR7xx4gNGwlN+AITYX1WJSfHDoc=";
  cargoBuildFlags = [
    "-p"
    "exo"
  ];
  cargoTestFlags = [
    "-p"
    "executor"
    "-p"
    "exo"
    "--lib"
    "--bins"
  ];

  nativeBuildInputs = [
    unstable.cmake
    unstable.pkg-config
  ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/exo secret login-chatgpt --help | grep -F 'browser device code'
    runHook postInstallCheck
  '';

  meta = {
    description = "Agent harness with ChatGPT subscription authentication";
    homepage = "https://github.com/exoharness/exo";
    license = lib.licenses.mit;
    mainProgram = "exo";
    platforms = lib.platforms.unix;
  };
}
