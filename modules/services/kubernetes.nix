{ config, lib, pkgs, ... }:

{
  my = {
    packages = with pkgs; [ kubectl kubernetes-helm k9s ];

    alias.k = "kubectl";
  };
}
