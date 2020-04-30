{ config, lib, pkgs, ... }:

{
  my.packages = with pkgs; [
    aerc
    # HTML rendering
    w3m
    dante
  ];
}
