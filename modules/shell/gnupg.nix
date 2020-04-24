{ config, lib, pkgs, ... }:

{
  my = {
    packages = with pkgs; [ gnupg pinentry ];
    env.GNUPGHOME = "$XDG_CONFIG_HOME/gnupg";

    # HACK Without this config file you get "No pinentry program" on 20.03.
    #      program.gnupg.agent.pinentryFlavor doesn't appear to work, and this
    #      is cleaner than overriding the systemd unit.
    home.xdg.configFile."gnupg/gpg-agent.conf" = {
      text = ''
        allow-emacs-pinentry
        default-cache-ttl 1800
        pinentry-program ${pkgs.pinentry.gtk2}/bin/pinentry
      '';
    };

  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
