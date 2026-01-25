# ErgoDox EZ firmware builder
#
# Builds QMK firmware for ErgoDox EZ using ZSA's firmware25 branch.
# Cross-compiles with AVR toolchain on Darwin.
#
# Usage in flake.nix:
#   ergodox-firmware = pkgs.callPackage ./packages/ergodox-firmware.nix {
#     keymapSrc = ./config/ergodox/firmware/ergo-drifter/zsa_..._source;
#   };
#
# To update ZSA QMK firmware:
#   1. Get new SHA: git ls-remote https://github.com/zsa/qmk_firmware.git firmware25
#   2. Update `zsaRev` below
#   3. Set `zsaHash` to lib.fakeHash
#   4. Build to get correct hash: nix build .#ergodox-firmware 2>&1 | grep "got:"
#   5. Update `zsaHash` with the correct value
{
  lib,
  stdenv,
  runCommand,
  fetchFromGitHub,
  pkgsCross,
  gnumake,
  python3,
  git,
  qmk,
  # Keymap source - override in flake.nix callPackage
  # Default is a dummy that fails at build time (not evaluation time)
  keymapSrc ? runCommand "ergodox-keymapSrc-missing" { } ''
    echo "ERROR: ergodox-firmware requires keymapSrc argument"
    echo "Usage: callPackage ./packages/ergodox-firmware.nix { keymapSrc = ./path/to/source; }"
    exit 1
  '',
  # ZSA QMK firmware version - update these when upgrading
  zsaRev ? "a07f8e6c7d62b814c495dfd16694a389a3855e08", # firmware25 branch
  zsaHash ? "sha256-6vU7nt6bYcdx958bgcb6gEiCHmn4Cv0OAPAnvt9yhWI=",
}:

let
  avrPkgs = pkgsCross.avr;
  zsaQmkFirmware = fetchFromGitHub {
    owner = "zsa";
    repo = "qmk_firmware";
    rev = zsaRev;
    hash = zsaHash;
    fetchSubmodules = true;
  };
in
stdenv.mkDerivation {
  pname = "ergodox-ergo-drifter-firmware";
  version = "unstable-2025-01-21";

  src = zsaQmkFirmware;

  nativeBuildInputs = [
    gnumake
    python3
    git
    qmk
    avrPkgs.buildPackages.gcc
    avrPkgs.buildPackages.binutils
  ];

  postPatch = ''
    patchShebangs .
    mkdir -p keyboards/zsa/ergodox_ez/m32u4/keymaps/ergo-drifter
    cp -r ${keymapSrc}/* keyboards/zsa/ergodox_ez/m32u4/keymaps/ergo-drifter/
  '';

  buildPhase = ''
    runHook preBuild
    make zsa/ergodox_ez/m32u4:ergo-drifter
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    install -Dm444 zsa_ergodox_ez_m32u4_base_ergo-drifter.hex $out/
    cd $out && md5sum *.hex > checksum.md5
    runHook postInstall
  '';

  dontFixup = true;

  meta = {
    description = "Ergodox EZ firmware (ergo-drifter layout)";
    homepage = "https://github.com/zsa/qmk_firmware";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.darwin; # Cross-compilation only tested on Darwin
  };
}
