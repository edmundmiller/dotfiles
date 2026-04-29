{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
let
  mkAmoxide = import ./_amoxide-common.nix {
    inherit
      lib
      rustPlatform
      fetchFromGitHub
      ;
  };
in
(mkAmoxide "amoxide-tui" "0.7.0").overrideAttrs (_: {
  meta.mainProgram = "am-tui";
})
