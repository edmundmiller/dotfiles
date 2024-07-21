{
  config,
  home-manager,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  name = "Edmund Miller";
  maildir = "/home/emiller/.mail";
  email = "edmund.a.miller@gmail.com";

  cfg = config.modules.desktop.apps.mail.accounts;
in {
  options.modules.desktop.apps.mail.accounts = {enable = mkBoolOpt false;};

  home-manager.users.emiller.accounts.email = {
      maildirBasePath = "${maildir}";
      accounts = {
        Gmail = {
          address = "${email}";
          userName = "${email}";
          flavor = "gmail.com";
          passwordCommand = "${lib.getExe' pkgs._1password "op read op://Moni and Ed/Edmund Google/password"}";
        program =
          primary = true;
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
            patterns = ["*" "[Gmail]*"]; # "[Gmail]/Sent Mail" ];
          };
          realName = "${name}";
        };
        UTD = {
          address = "Edmund.Miller@utdallas.edu";
          userName = "eam150030@utdallas.edu";
          aliases = ["eam150030@utdallas.edu"];
          flavor = "plain";
          passwordCommand = "${pkgs.pass}/bin/pass utd";
          mbsync = {
            enable = true;
            create = "both";
            expunge = "both";
            patterns = ["*"];
            extraConfig.account = {AuthMechs = "LOGIN";};
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
  };
}
