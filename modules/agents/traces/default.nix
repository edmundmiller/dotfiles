{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents.traces;
  package = pkgs.my.agent-traces;
  writeToken = "${config.user.home}/.local/share/agenix/agent-traces-r2-write-token";
  readToken = "${config.user.home}/.local/share/agenix/agent-traces-r2-read-token";
in
{
  options.modules.agents.traces = {
    enable = mkBoolOpt false;
    hour = mkOpt types.int 3;
    minute = mkOpt types.int 30;
    catalogUri = mkOpt types.str "";
    warehouse = mkOpt types.str "";
  };

  config = mkIf (cfg.enable && isDarwin) {
    assertions = [
      {
        assertion = cfg.catalogUri != "" && cfg.warehouse != "";
        message = "modules.agents.traces requires catalogUri and warehouse";
      }
    ];

    user.packages = [ package ];

    home-manager.users.${config.user.name} = {
      home.file.".local/share/agent-traces/explore.py".source = package.passthru.notebook;
    };

    launchd.user.agents.agent-traces = {
      command = "${package}/bin/python -m agent_traces.ingest";
      serviceConfig = {
        StartCalendarInterval = {
          Hour = cfg.hour;
          Minute = cfg.minute;
        };
        StandardOutPath = "${config.user.home}/Library/Logs/agent-traces.log";
        StandardErrorPath = "${config.user.home}/Library/Logs/agent-traces.err.log";
        EnvironmentVariables = {
          HOME = config.user.home;
          PATH = "/etc/profiles/per-user/${config.user.name}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          PYTHONUNBUFFERED = "1";
          AGENT_TRACES_CATALOG_URI = cfg.catalogUri;
          AGENT_TRACES_WAREHOUSE = cfg.warehouse;
          AGENT_TRACES_WRITE_TOKEN_FILE = writeToken;
          AGENT_TRACES_READ_TOKEN_FILE = readToken;
        };
      };
    };
  };
}
