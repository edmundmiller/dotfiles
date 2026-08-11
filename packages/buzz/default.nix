{
  cacert,
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "buzz";
  version = "0.5.2";

  src = fetchFromGitHub {
    owner = "block";
    repo = "buzz";
    rev = "v${version}";
    hash = "sha256-VWqoIS5FMyou6fEuuUq1OUIPycAtn0kVLbm5yCQAsOs=";
  };

  cargoHash = "sha256-0a0SJqDjSTWXU6k3yZ6iisDaUdnHqzjZU33ItzGs8AY=";
  patches = [ ./patches/exact-respond-to-allowlist.patch ];

  cargoBuildFlags = [
    "--package=buzz-acp"
    "--package=buzz-cli"
    "--package=git-credential-nostr"
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
