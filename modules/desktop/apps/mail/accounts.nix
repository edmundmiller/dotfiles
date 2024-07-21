{
  config,
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

  config = mkIf cfg.enable {
    home-manager.users.emiller.accounts.email = {
      maildirBasePath = "${maildir}";
      accounts = {
        Gmail = {
          address = "${email}";
          userName = "${email}";
          flavor = "gmail.com";
          primary = true;
          passwordCommand = "op read 'op://Moni and Ed/Edmund Google/password'";
          realName = "${name}";
          # msmtp.enable = true;
        };
        UTD = {
          address = "Edmund.Miller@utdallas.edu";
          userName = "eam150030@utdallas.edu";
          aliases = ["eam150030@utdallas.edu"];
          flavor = "outlook.office365.com";
          passwordCommand = "op read 'op://Moni and Ed/UTDallas/password'";
          realName = "${name}";
          # msmtp.enable = true;
        };
      };
    };
  };
}
