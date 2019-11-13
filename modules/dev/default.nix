{ config, lib, pkgs, ... }:

{
  imports = [
    ./cc.nix
    ./node.nix
    ./python.nix
    ./clojure.nix
    ./R.nix
    ./rust.nix
    ./solidity.nix
    ./zsh.nix
    ./terraform.nix
    ./nixops.nix

    ../misc/docker.nix
    ../misc/virtualbox.nix
  ];
}
