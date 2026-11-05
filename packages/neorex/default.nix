{
  lib,
  stdenv,
  fetchFromGitHub,
  inputs,
}:
stdenv.mkDerivation {
  pname = "neorex";
  version = "0.0.0-unstable-2026-10-31";

  src = fetchFromGitHub {
    owner = "alexrlocke";
    repo = "neorex";
    rev = "e3062d2cd731315dba99faea21672b13e476ab63";
    hash = "sha256-PIzF80Gpq/5uKPQNxdycYfuiKVnQ3LxuByE1YbXSFtA=";
  };

  # Host nixpkgs stops at Zig 0.15. nixpkgs-jj already carries Zig 0.17.
  # The zon file's only dependency is a lazy Ghostty pin for -Dgolden tests.
  nativeBuildInputs = [
    inputs.nixpkgs-jj.legacyPackages.${stdenv.hostPlatform.system}.zig_0_17.hook
  ];

  meta = {
    description = "Rex-native Neovim frontend that opens splits as Rex panes";
    homepage = "https://github.com/alexrlocke/neorex";
    license = lib.licenses.mit;
    mainProgram = "neorex";
    platforms = lib.platforms.darwin;
  };
}
