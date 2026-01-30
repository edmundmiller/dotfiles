{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.mail.aerc;
in
{
  options.modules.desktop.apps.mail.aerc = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {
      accounts.email = {
        accounts = {
          Gmail.aerc = {
            enable = true;
          };

          fastmail.aerc = {
            enable = true;
          };
          UTD.aerc = {
            enable = false;
            imapAuth = "oauthbearer";
            # NOTE https://atlas.utdallas.edu/TDClient/30/Portal/KB/ArticleDet?ID=301
            # imapOauth2Params = {
            #   client_id = "8d281d1d-9c4d-4bf7-b16e-032d15de9f6c"; # Tenant
            #   client_secret = "a9170526-040b-453c-aac5-36155cba7a26"; # Application ID
            #   scope = "";
            #   token_endpoint = "https://outlook.office365.com/EWS/Exchange.asmx";
            # };
          };
        };
      };

      programs.aerc = {
        enable = true;
        extraConfig.general.unsafe-accounts-conf = true;
        #   # FIXME Still doesn't have the right permissions
        #   # "aerc/accounts.conf".source = <config/aerc/accounts.conf>;
        #   extraConfig = "${configDir}/aerc/aerc.conf";
        #   "aerc/binds.conf".source = "${configDir}/aerc/binds.conf";
        #   "aerc/templates" = {
        #     source = "${configDir}/aerc/templates";
        #     recursive = true;
        #   };
      };
    };
  };
}
