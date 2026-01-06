{ config, lib, ... }:
with lib;
with lib.my;
let
  name = "Edmund Miller";
  homeDir = config.users.users.${config.user.name}.home;
  maildir = "${homeDir}/.mail";
  email = "edmund.a.miller@gmail.com";

  cfg = config.modules.desktop.apps.mail.accounts;
in
{
  options.modules.desktop.apps.mail.accounts = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name}.accounts.email = {
      maildirBasePath = "${maildir}";
      accounts = {
        Gmail = {
          address = "${email}";
          userName = "${email}";
          flavor = "gmail.com";
          passwordCommand = "op read 'op://Moni and Ed/Edmund Google/password'";
          realName = "${name}";
          # msmtp.enable = true;
        };
        fastmail = {
          address = "me@edmundmiller.dev";
          userName = "me@edmundmiller.dev";
          aliases = [ "hello@edmundmiller.dev" ];
          flavor = "fastmail.com";
          passwordCommand = "op read 'op://Private/Fastmail/new-password '";
          realName = "${name}";
          primary = true;
          # msmtp.enable = true;
        };
        UTD = {
          address = "Edmund.Miller@utdallas.edu";
          userName = "eam150030@utdallas.edu";
          aliases = [ "eam150030@utdallas.edu" ];
          flavor = "outlook.office365.com";
          passwordCommand = "op read 'op://Moni and Ed/UTDallas/password'";
          realName = "${name}";
          # msmtp.enable = true;
        };
      };
    };
  };
}
