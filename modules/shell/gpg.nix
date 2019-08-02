{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ pinentry_emacs pinentry];
}
