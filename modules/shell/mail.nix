{ config, options, lib, pkgs, ... }:

with lib;
let
  name = "Edmund Miller";
  maildir = "/home/emiller/.mail";
  email = "edmund.a.miller@gmail.com";
  protonmail = "edmund.a.miller@protonmail.com";
  notmuchrc = "/home/emiller/.config/notmuch/notmuchrc";
  imapfilterconfig = "/home/emiller/.config/imapfilter/config.lua";
in {
  options.modules.shell.mail = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  imports = [ ./davmail.nix ];
  config = mkIf config.modules.shell.mail.enable {
    my = {
      packages = with pkgs; [
        unstable.mu
        isync
        imapfilter
        (makeDesktopItem {
          name = "mu4e";
          desktopName = "mu4e";
          exec = ''
            emacsclient -create-frame --alternate-editor="" --no-wait --eval '(progn (x-focus-frame nil) (mu4e-compose-from-mailto "%u"))'
          '';
          icon = "emacs";
          mimeType = "x-scheme-handler/mailto";
          categories = "Email";
        })
      ];
      home = {
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
                patterns = [ "*" "[Gmail]*" ]; # "[Gmail]/Sent Mail" ];
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
                patterns = [ "*" "[Gmail]*" ]; # "[Gmail]/Sent Mail" ];
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
                extraConfig.account = { AuthMechs = "LOGIN"; };
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

        services = {
          mbsync = {
            enable = true;
            frequency = "*:0/15";
            preExec = ''
              ${pkgs.isync}/bin/mbsync -Ha &&\
              ${pkgs.imapfilter}/bin/imapfilter -c ${imapfilterconfig} -t /etc/ssl/certs/ca-bundle.crt -v
            '';
            postExec = "${pkgs.unstable.mu}/bin/mu index";
          };
        };
      };

      home.xdg.configFile = {
        "imapfilter" = {
          source = <config/imapfilter>;
          recursive = true;
        };
      };
    };
  };
}
