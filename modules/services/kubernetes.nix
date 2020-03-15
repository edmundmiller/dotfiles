{ config, lib, pkgs, ... }:

{
  my = {
    packages = with pkgs; [ kubectl k9s ];

    alias.k = "kubectl";
  };
}
