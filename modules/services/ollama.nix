{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.services.ollama;
in {
  options.modules.services.ollama = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    systemd = {
      services.ollama = {
        wantedBy = ["multi-user.target"];
        description = "Server for local large language models";
        after = ["network.target"];
        environment = {
          HOME = "%S/ollama";
          OLLAMA_MODELS = "%S/ollama/models";
        };
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.unstable.ollama} serve";
          WorkingDirectory = "/var/lib/ollama";
          StateDirectory = ["ollama"];
          DynamicUser = true;
        };
      };
    };

    environment.systemPackages = [pkgs.unstable.ollama];
  };
}
