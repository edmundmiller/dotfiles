# Pure nix build for Ergodox EZ firmware
#
# Builds the ergo-drifter keymap from ZSA's QMK firmware fork.
# No ~/qmk_firmware directory needed - everything is built in the nix store.
#
# Usage:
#   nix build .#ergodox-firmware
#   hey ergodox-build
#
{ stdenv
, lib
, fetchFromGitHub
, python3
, gnumake
, git
, avrPkgs  # Cross-compilation toolchain, passed from flake.nix
}:

let
  # NOTE: To update, check https://github.com/zsa/qmk_firmware/tree/firmware25
  # for the latest commit SHA and run:
  #   nix build .#ergodox-firmware 2>&1 | grep "got:" | cut -d: -f2 | tr -d ' '
  # to get the new hash.
  zsaQmkFirmware = fetchFromGitHub {
    owner = "zsa";
    repo = "qmk_firmware";
    rev = "a07f8e6c7d62b814c495dfd16694a389a3855e08"; # firmware25 branch
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will be replaced on first build
    fetchSubmodules = true;
  };

  keymapSrc = ../config/ergodox/firmware/ergo-drifter/zsa_ergodox_ez_m32u4_base_ergo-drifter-fork-fork_source;
in
stdenv.mkDerivation {
  pname = "ergodox-ergo-drifter-firmware";
  version = "unstable-2025-01-21";

  src = zsaQmkFirmware;

  nativeBuildInputs = [
    gnumake
    python3
    git
    avrPkgs.buildPackages.gcc
    avrPkgs.buildPackages.binutils
    avrPkgs.avrlibc
  ];

  postPatch = ''
    patchShebangs .

    # Copy keymap source into build tree
    mkdir -p keyboards/zsa/ergodox_ez/m32u4/keymaps/ergo-drifter
    cp -r ${keymapSrc}/* keyboards/zsa/ergodox_ez/m32u4/keymaps/ergo-drifter/
  '';

  buildPhase = ''
    runHook preBuild
    
    # QMK build uses make under the hood
    make zsa/ergodox_ez/m32u4:ergo-drifter
    
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out
    install -Dm444 zsa_ergodox_ez_m32u4_ergo-drifter.hex $out/
    
    # Generate md5 for verification
    cd $out
    md5sum *.hex > checksum.md5
    
    runHook postInstall
  '';

  # Critical: don't patch firmware binary!
  dontFixup = true;

  meta = {
    description = "Ergodox EZ firmware (ergo-drifter layout)";
    homepage = "https://github.com/zsa/qmk_firmware";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.all;
    maintainers = [ ];
  };
}
