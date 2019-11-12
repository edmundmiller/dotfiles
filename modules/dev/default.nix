{ config, lib, pkgs, ... }:

{
  imports = [
    ./dev/cc.nix
    ./dev/node.nix
    ./dev/python.nix
    ./dev/clojure.nix
    ./dev/R.nix
    ./dev/rust.nix
    ./dev/solidity.nix
    ./dev/zsh.nix
    ./dev/terraform.nix
    ./dev/nixops.nix

    ./misc/docker.nix
    ./misc/virtualbox.nix
  ];
}
