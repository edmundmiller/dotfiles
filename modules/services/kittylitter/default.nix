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

  agentNames = [
    "codex"
    "pi"
    "hermes"
    "amp"
    "opencode"
    "claude"
    "droid"
    "devin"
    "grok"
  ];

  agentDefaults = {
    codex = {
      bin = "codex";
      host = "127.0.0.1";
      port = 8390;
    };
    pi.bin = "pi";
    hermes = {
      bin = "hermes";
      api_base = "http://127.0.0.1:8642";
    };
    amp = {
      bin = "amp";
      api_key_env = "AMP_API_KEY";
      dangerously_allow_all = true;
    };
    opencode.bin = "opencode";
    claude = {
      bin = "claude";
      bypass_permissions = true;
    };
    droid = {
      bin = "droid";
      api_key_env = "FACTORY_API_KEY";
    };
    devin.bin = "devin";
    grok = {
      bin = "grok";
      no_leader = true;
      always_approve = false;
      reasoning_effort = "medium";
    };
  };

  managedAgents = lib.genAttrs agentNames (
    name: agentDefaults.${name} // { enabled = lib.elem name cfg.enabledAgents; }
  );

  tomlFormat = pkgs.formats.toml { };

  managedAgentsConfig = tomlFormat.generate "kittylitter-managed-agents.toml" {
    agents = managedAgents;
  };

  defaultHostConfig = tomlFormat.generate "kittylitter-host.toml" {
    agents = managedAgents;
    session = {
      replay_max_msgs = 2048;
      replay_max_bytes = 16777216;
      idle_ttl_secs = 600;
      pending_grace_secs = 60;
    };
  };

  droidCli = pkgs.writeShellScriptBin "droid" ''
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:''${PATH:-}"
    exec ${pkgs.bun}/bin/bunx --bun droid "$@"
  '';

  agentPath = lib.makeBinPath [
    cfg.package
    pkgs.llm-agents.codex
    pkgs.claude-code
    pkgs.bun
    pkgs.nodejs
    droidCli
  ];

  servicePath = "${agentPath}:${cfg.homeDir}/.bun/bin:${cfg.homeDir}/.local/bin:${cfg.homeDir}/.cache/npm/bin:/etc/profiles/per-user/${cfg.user}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";

  configPrep = pkgs.writeShellScript "kittylitter-config-prep" ''
    set -euo pipefail

    config_dir=${lib.escapeShellArg cfg.configDir}
    config_file="$config_dir/host.toml"

    mkdir -p "$config_dir"

    if [ ! -f "$config_file" ]; then
      install -m 600 ${defaultHostConfig} "$config_file"
      exit 0
    fi

    # Preserve pairing tokens/session settings, but converge managed agent
    # sections to this host's Nix configuration.
    tmp="$(${pkgs.coreutils}/bin/mktemp)"
    ${pkgs.gawk}/bin/awk '
      BEGIN { skip = 0 }
      /^\[agents\.(codex|pi|hermes|amp|opencode|claude|droid|devin|grok)\]$/ { skip = 1; next }
      /^\[/ { skip = 0 }
      !skip { print }
    ' "$config_file" > "$tmp"
    cat "$tmp" > "$config_file"
    rm -f "$tmp"
    printf '\n' >> "$config_file"
    cat ${managedAgentsConfig} >> "$config_file"
  '';

  launchdRunner = pkgs.writeShellScript "kittylitter-launchd" ''
    set -euo pipefail

    ${configPrep}

    export HOME=${lib.escapeShellArg cfg.homeDir}
    export XDG_CONFIG_HOME=${lib.escapeShellArg "${cfg.homeDir}/.config"}
    export PATH=${lib.escapeShellArg servicePath}

    # Runtime cleanup is intentionally duplicated from activation so a stale
    # npx/com.sigkitten daemon cannot block the managed Nix launchd job after
    # logouts, rollbacks, or manual starts.
    launchctl bootout "gui/$(${pkgs.coreutils}/bin/id -u)/com.sigkitten.kittylitter" 2>/dev/null || true
    rm -f ${lib.escapeShellArg "${cfg.homeDir}/Library/LaunchAgents/com.sigkitten.kittylitter.plist"}
    /usr/bin/pkill -u ${lib.escapeShellArg cfg.user} -f '/_npx/.*/kittylitter serve' 2>/dev/null || true
    ${cfg.package}/bin/kittylitter stop 2>/dev/null || true

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
    enabledAgents = mkOpt (types.listOf (types.enum agentNames)) agentNames;
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
        if ${pkgs.systemd}/bin/systemctl list-unit-files --no-legend kittylitter.service | ${pkgs.gnugrep}/bin/grep -q .; then
          ${pkgs.systemd}/bin/systemctl disable --now kittylitter.service || true
        fi
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
