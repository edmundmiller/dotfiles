{ inputs, pkgs }:
let
  metadata = builtins.fromJSON (builtins.readFile ./package-harness.json);
  patches = map (patch: ./. + "/${patch}") metadata.patches;
in
inputs.hunk.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ patches;
})
