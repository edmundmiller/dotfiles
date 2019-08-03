{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
      shfmt
      shellcheck
  ];
}
