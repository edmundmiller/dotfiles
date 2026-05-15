{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  gcc,
  openssl,
  zlib,
}:

let
  version = "0.1.0-alpha.4";

  sources = {
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/Ataraxy-Labs/lazydiff/releases/download/v${version}/lazydiff-macos-arm64.tar.gz";
      hash = "sha256-M/9G/DEha1HAn1WKElK9zcF79YtvHxIevzCgIBjc96k=";
    };
    "x86_64-linux" = fetchurl {
      url = "https://github.com/Ataraxy-Labs/lazydiff/releases/download/v${version}/lazydiff-linux-x86_64.tar.gz";
      hash = "sha256-CKGYMYxwJ7DGqMWfp+QX3KyFUHrw1VQ3CoCAKLI/kI4=";
    };
  };
in

stdenvNoCC.mkDerivation {
  pname = "lazydiff";
  inherit version;

  src =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "unsupported system: ${stdenvNoCC.hostPlatform.system}");

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    gcc.cc.lib
    openssl
    zlib
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 lazydiff $out/bin/lazydiff
    runHook postInstall
  '';

  meta = with lib; {
    description = "Fast terminal UI for reviewing Git diffs and GitHub pull requests";
    homepage = "https://github.com/Ataraxy-Labs/lazydiff";
    license = licenses.mit;
    mainProgram = "lazydiff";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
}
