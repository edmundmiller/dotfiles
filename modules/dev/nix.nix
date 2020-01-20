{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ nixfmt nixops ];
}
