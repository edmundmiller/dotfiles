# Hash-pinned Mise releases without compiling the Rust toolchain.
# Keep tooling on its existing release while hosts upgrade independently.
{
  lib,
  fetchurl,
  runCommand,
  stdenvNoCC,
  version ? "2026.7.5",
}:
let
  releases = {
    "2026.7.5" = {
      x86_64-linux = {
        platform = "linux-x64-musl";
        hash = "sha256-zd9tYQ9ApuPD5aWehguecuRrFZrSVLm9qV4Ae6Mvuyg=";
      };
      aarch64-darwin = {
        platform = "macos-arm64";
        hash = "sha256-pFbGWQfoM0YZ13+hUr3PkCP93A2qA9R/vobQMtv1ZbA=";
      };
    };
    "2026.11.8" = {
      x86_64-linux = {
        platform = "linux-x64-musl";
        hash = "sha256-H+ZEiambYie39+Z65N0yk8IOy7zXSxNnRWAQNZOD5xI=";
      };
      aarch64-darwin = {
        platform = "macos-arm64";
        hash = "sha256-PjkOy89/A+kecskgokig8UnwDXeuldN+oXNqHHtC/uY=";
      };
    };
  };
  release = releases.${version}.${stdenvNoCC.hostPlatform.system};
  binary = fetchurl {
    url = "https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-${release.platform}";
    inherit (release) hash;
  };
in
runCommand "mise-binary-${version}"
  {
    inherit version;
    meta = {
      description = "Hash-pinned upstream Mise binary";
      homepage = "https://mise.jdx.dev";
      license = lib.licenses.mit;
      mainProgram = "mise";
      platforms = builtins.attrNames releases.${version};
    };
  }
  ''
    install -Dm755 ${binary} "$out/bin/mise"
    # Version reporting must not check the network in a Nix sandbox.
    CI=1 "$out/bin/mise" --version | grep -F '${version}'
  ''
