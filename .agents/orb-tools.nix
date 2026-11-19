# Snapshot only public prerequisites, without evaluating the private root flake.
let
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  locked = lock.nodes.${lock.nodes.root.inputs.nixpkgs}.locked;
  source =
    if locked.type == "github" then
      assert locked.owner == "NixOS" && locked.repo == "nixpkgs";
      builtins.fetchTree {
        type = "github";
        inherit (locked)
          owner
          repo
          rev
          narHash
          ;
      }
    else
      assert locked.type == "tarball";
      assert builtins.match "https://releases\\.nixos\\.org/.*" locked.url != null;
      builtins.fetchTree {
        type = "tarball";
        inherit (locked) url narHash;
      };
  pkgs = import source.outPath { system = builtins.currentSystem; };
  mise = pkgs.callPackage ./mise-binary.nix { };
  hey = pkgs.callPackage ../packages/hey {
    inherit mise;
    my.bend = pkgs.callPackage ../packages/bend { };
  };
in
pkgs.buildEnv {
  name = "dotfiles-orb-tools";
  paths = [
    hey
    mise
    pkgs.prek
    pkgs.jujutsu
  ];
}
