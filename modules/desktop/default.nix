{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
{
  options.modules.desktop.enable = mkBoolOpt false;

  # Shared Linux desktop packages, independent of a window system or compositor.
  config = mkIf config.modules.desktop.enable {
    "user.packages" = with pkgs; [
      feh
      libqalculate
    ];

    fonts = {
      fontDir.enable = true;
      enableGhostscriptFonts = true;
      packages = with pkgs; [
        ubuntu-classic
        dejavu_fonts
        fira
        jetbrains-mono
        symbola
        commit-mono
        monaspace
        unstable.nerd-fonts.monaspace
        noto-fonts
        noto-fonts-cjk-sans
      ];
    };
  };
}
