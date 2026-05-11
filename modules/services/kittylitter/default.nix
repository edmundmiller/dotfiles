# Kittylitter - patched Alleycat bridge daemon for remote agent pairing
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
  cfg = config.modules.services.kittylitter;

  defaultHostConfig = pkgs.writeText "kittylitter-host.toml" ''
    [agents.codex]
    enabled = true
    bin = "codex"
    host = "127.0.0.1"
    port = 8390

    [agents.pi]
    enabled = true
    bin = "pi"

    [agents.opencode]
    enabled = true
    bin = "opencode"

    [agents.claude]
    enabled = true
    bin = "claude"
    bypass_permissions = true

    [session]
    replay_max_msgs = 2048
    replay_max_bytes = 16777216
    idle_ttl_secs = 600
    pending_grace_secs = 60
  '';

  piAgentConfig = pkgs.writeText "kittylitter-pi-agent.toml" ''
    [agents.pi]
    enabled = true
    bin = "pi"
  '';

  agentPath = lib.makeBinPath [
    cfg.package
    pkgs.codex
    pkgs.claude-code
    pkgs.bun
    pkgs.nodejs
  ];

  servicePath = "${agentPath}:${cfg.homeDir}/.bun/bin:${cfg.homeDir}/.local/bin:${cfg.homeDir}/.cache/npm/bin:/etc/profiles/per-user/${cfg.user}/bin:/run/current-system/sw/bin";

  configPrep = pkgs.writeShellScript "kittylitter-config-prep" ''
    set -euo pipefail

    config_dir=${lib.escapeShellArg cfg.configDir}
    config_file="$config_dir/host.toml"

    mkdir -p "$config_dir"

    if [ ! -f "$config_file" ]; then
      install -m 600 ${defaultHostConfig} "$config_file"
      exit 0
    fi

    ${pkgs.perl}/bin/perl -0pi -e 's/(\[agents\.pi\]\n(?:(?!\n\[).)*?enabled\s*=\s*)false/$1true/s' "$config_file"

    if ! ${pkgs.gnugrep}/bin/grep -q '^\[agents\.pi\]' "$config_file"; then
      printf '\n' >> "$config_file"
      cat ${piAgentConfig} >> "$config_file"
    fi
  '';

  launchdRunner = pkgs.writeShellScript "kittylitter-launchd" ''
    set -euo pipefail

    ${configPrep}

    export HOME=${lib.escapeShellArg cfg.homeDir}
    export XDG_CONFIG_HOME=${lib.escapeShellArg "${cfg.homeDir}/.config"}
    export PATH=${lib.escapeShellArg servicePath}

    exec ${cfg.package}/bin/kittylitter serve
  '';
in
{
  options.modules.services.kittylitter = {
    enable = mkBoolOpt false;
    package = mkOpt types.package pkgs.my.kittylitter;
    user = mkOpt types.str config.user.name;
    homeDir = mkOpt types.str config.user.home;
    configDir = mkOpt types.str "${cfg.homeDir}/.config/kittylitter";
  };

  config = mkIf cfg.enable (mkMerge [
    { environment.systemPackages = [ cfg.package ]; }

    (optionalAttrs isDarwin {
      launchd.user.agents.kittylitter = {
        command = "${launchdRunner}";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/tmp/kittylitter.log";
          StandardErrorPath = "/tmp/kittylitter.err";
        };
      };

      system.activationScripts.disableLegacyKittylitter.text = ''
        uid="$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg cfg.user} 2>/dev/null || true)"
        if [ -n "$uid" ]; then
          launchctl bootout "gui/$uid/com.sigkitten.kittylitter" 2>/dev/null || true
        fi
        legacy_plist=${lib.escapeShellArg "${cfg.homeDir}/Library/LaunchAgents/com.sigkitten.kittylitter.plist"}
        if [ -f "$legacy_plist" ] && ! [ -L "$legacy_plist" ]; then
          rm -f "$legacy_plist"
        fi
      '';
    })

    (optionalAttrs (!isDarwin) {
      home-manager.users.${cfg.user}.systemd.user.services.kittylitter = {
        Unit = {
          Description = "Patched kittylitter Alleycat bridge daemon";
          After = [ "network-online.target" ];
        };
        Service = {
          Type = "simple";
          ExecStartPre = "${configPrep}";
          ExecStart = "${cfg.package}/bin/kittylitter serve";
          Restart = "on-failure";
          RestartSec = "5s";
          Environment = [
            "HOME=${cfg.homeDir}"
            "XDG_CONFIG_HOME=${cfg.homeDir}/.config"
            "PATH=${servicePath}"
          ];
        };
        Install.WantedBy = [ "default.target" ];
      };

      system.activationScripts.disableLegacyKittylitter = ''
        ${pkgs.systemd}/bin/systemctl disable --now kittylitter.service || true
        if id ${lib.escapeShellArg cfg.user} >/dev/null 2>&1; then
          ${pkgs.procps}/bin/pkill -u ${lib.escapeShellArg cfg.user} -f '/_npx/.*/kittylitter serve' || true
          legacy_unit=${lib.escapeShellArg "${cfg.homeDir}/.config/systemd/user/kittylitter.service"}
          if [ -f "$legacy_unit" ] && ! [ -L "$legacy_unit" ]; then
            rm -f "$legacy_unit"
          fi
        fi
      '';
    })
  ]);
}
