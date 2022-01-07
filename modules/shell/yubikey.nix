{ config, options, pkgs, lib, ... }:

with lib;
with lib.my;
let cfg = config.modules.shell.yubikey;
in
{
  options.modules.shell.yubikey = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      gnupg
      yubikey-manager-qt
      yubikey-manager
      yubikey-personalization
    ];

    services.udev.packages = [ pkgs.yubikey-personalization pkgs.libu2f-host ];
    # According to https://github.com/NixOS/nixpkgs/issues/85127
    # This is no longer necessary
    # services.pcscd.enable = true;

    # FIXME
    environment.shellInit = ''
      export GPG_TTY="$(tty)"
      gpg-connect-agent /bye
      export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    '';

    programs = {
      ssh.startAgent = false;
      gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };
    };
  };
}
