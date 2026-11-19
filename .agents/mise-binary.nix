# Checks and Orb setup need real Mise, but must not compile its Rust toolchain.
# Keep host packages on pkgs.mise; this pin only supplies test/Orb executables.
{
  lib,
  fetchurl,
  runCommand,
  stdenvNoCC,
}:
let
  version = "2026.7.5";
  releases = {
    x86_64-linux = {
      platform = "linux-x64-musl";
      hash = "sha256-zd9tYQ9ApuPD5aWehguecuRrFZrSVLm9qV4Ae6Mvuyg=";
    };
    aarch64-darwin = {
      platform = "macos-arm64";
      hash = "sha256-pFbGWQfoM0YZ13+hUr3PkCP93A2qA9R/vobQMtv1ZbA=";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system};
  binary = fetchurl {
    url = "https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-${release.platform}";
    inherit (release) hash;
  };
in
runCommand "mise-binary-${version}"
  {
    meta = {
      description = "Upstream Mise binary for checks and Orb setup";
      homepage = "https://mise.jdx.dev";
      license = lib.licenses.mit;
      mainProgram = "mise";
      platforms = builtins.attrNames releases;
    };
  }
  ''
    install -Dm755 ${binary} "$out/bin/mise"
    # Version reporting must not check the network in a Nix sandbox.
    CI=1 "$out/bin/mise" --version | grep -F '${version}'
  ''
