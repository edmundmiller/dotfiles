{ config, lib, pkgs, ... }:

let bg-img = "/etc/dotfiles/assets/wallpapers/functionalDNA_orange.png";
in {
  services.xserver = {
    displayManager.lightdm.greeters.mini = {
      enable = true;
      user = "emiller";
      extraConfig = ''
        [greeter]
        show-password-label = false
        [greeter-theme]
        background-image = "${bg-img}"
      '';
    };
    desktopManager.xterm.enable = false;
  };
}
