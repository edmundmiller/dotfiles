{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  name = "Edmund Miller";
  homeDir = config.users.users.${config.user.name}.home;
  maildir = "${homeDir}/.mail";
  email = "edmund.a.miller@gmail.com";

  cfg = config.modules.desktop.apps.mail.mbsync;
in
{
  options.modules.desktop.apps.mail.mbsync = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      unstable.mu
      isync
      imapfilter
      # (makeDesktopItem {
      #   name = "mu4e";
      #   desktopName = "mu4e";
      #   exec = ''
      #     emacsclient -create-frame --alternate-editor="" --no-wait --eval '(progn (x-focus-frame nil) (mu4e-compose-from-mailto "%u"))'
      #   '';
      #   icon = "emacs";
      #   mimeTypes = ["x-scheme-handler/mailto"];
      #   categories = [ "Email" ];
      # })
    ];
    home-manager.users.${config.user.name} = {
      accounts.email = {
        maildirBasePath = "${maildir}";
        accounts = {
          Gmail = {
            address = "${email}";
            userName = "${email}";
            flavor = "gmail.com";
            passwordCommand = "${pkgs.pass}/bin/pass Email/GmailApp";
            primary = true;
            # gpg.encryptByDefault = true;
            mbsync = {
              enable = true;
              create = "both";
              expunge = "both";
              patterns = [
                "*"
                "[Gmail]*"
              ]; # "[Gmail]/Sent Mail" ];
            };
            realName = "${name}";
            msmtp.enable = true;
          };
          Eman = {
            address = "eman0088@gmail.com";
            userName = "eman0088@gmail.com";
            flavor = "gmail.com";
            passwordCommand = "${pkgs.pass}/bin/pass oldGmail";
            mbsync = {
              enable = true;
              create = "both";
              expunge = "both";
              patterns = [
                "*"
                "[Gmail]*"
              ]; # "[Gmail]/Sent Mail" ];
            };
            realName = "${name}";
          };
          UTD = {
            address = "Edmund.Miller@utdallas.edu";
            userName = "eam150030@utdallas.edu";
            aliases = [ "eam150030@utdallas.edu" ];
            flavor = "plain";
            passwordCommand = "${pkgs.pass}/bin/pass utd";
            mbsync = {
              enable = true;
              create = "both";
              expunge = "both";
              patterns = [ "*" ];
              extraConfig.account = {
                AuthMechs = "LOGIN";
              };
            };
            imap = {
              host = "127.0.0.1";
              port = 1143;
              tls.enable = false;
            };
            realName = "${name}";
            msmtp.enable = true;
            smtp = {
              host = "127.0.0.1";
              port = 1025;
              tls.enable = false;
            };
          };
        };
      };

      programs = {
        msmtp.enable = true;
        mbsync.enable = true;
      };

      # Thanks to sparogy
      systemd.user.services.mbsync.environment = {
        "PASSWORD_STORE_DIR" = "$HOME/.secrets/password-store";
      };

      services = {
        mbsync = {
          enable = true;
          frequency = "*:0/15";
          postExec = "${pkgs.unstable.mu}/bin/mu index";
        };
      };
    };
  };
}
