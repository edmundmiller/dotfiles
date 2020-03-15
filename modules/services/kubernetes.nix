{ config, lib, pkgs, ... }:

{
  my = {
    packages = with pkgs; [ kubectl unstable.kubernetes-helm k9s ];

    alias.k = "kubectl";
  };
}
