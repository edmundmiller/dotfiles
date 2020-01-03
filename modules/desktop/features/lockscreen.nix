{ config, lib, pkgs, ... }:

let
  lockIMG =
    "/home/emiller/.dotfiles/assets/wallpapers/functionalDNA_orange.png";
in {
  environment.systemPackages = with pkgs; [ i3lock ];

  services.xserver.xautolock = {
    enable = true;
    enableNotifier = true;
    notifier = ''
      ${pkgs.libnotify}/bin/notify-send "Locking in 10 seconds"
    '';
    killer = "${pkgs.systemd}/bin/systemctl suspend";
    locker = "${pkgs.i3lock}/bin/i3lock -i ${lockIMG}";
    nowlocker = "${pkgs.i3lock}/bin/i3lock -i ${lockIMG}";
    time = 8;
  };
}
