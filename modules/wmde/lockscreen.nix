{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ i3lock ];

  services.xserver.xautolock = {
    enable = true;
    enableNotifier = true;
    notifier = ''
      ${pkgs.libnotify}/bin/notify-send "Locking in 10 seconds"
    '';
    killer = "${pkgs.systemd}/bin/systemctl suspend";
    locker =
    "${pkgs.i3lock}/bin/i3lock -i ~/.dotfiles/assets/wallpapers/blue-forest-landscape.2560x1440.jpg";
    nowlocker =
    "${pkgs.i3lock}/bin/i3lock -i ~/.dotfiles/assets/wallpapers/blue-forest-landscape.2560x1440.jpg";
    time = 8;
  };
}
