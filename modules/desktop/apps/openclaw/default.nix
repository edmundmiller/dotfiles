{
  config,
  lib,
  ...
}:

with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.openclaw;
  user = config.user.name;
  tokenPath = config.home-manager.users.${user}.age.secrets.openclaw-gateway-token.path;
in
{
  options.modules.desktop.apps.openclaw = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # Install OpenClaw.app via Homebrew cask
    homebrew.casks = [ "openclaw" ];

    home-manager.users.${user} =
      { lib, ... }:
      {
        programs.openclaw = {
          enable = true;
          # App installed via Homebrew — don't install via Nix
          installApp = false;

          instances.default = {
            enable = true;
            # App needs launchd to run
            launchd.enable = true;
            appDefaults = {
              enable = true;
              nixMode = true;
              # Attach to remote gateway, don't spawn local
              attachExistingOnly = true;
            };
            # GP2: connect to NUC gateway via Tailscale Serve (wss://)
            # Token injected at activation from agenix secret
            config.agents.defaults.thinkingDefault = "high";
            config.gateway = {
              mode = "remote";
              remote = {
                url = "wss://nuc.cinnamon-rooster.ts.net";
                transport = "direct";
                token = "__OPENCLAW_TOKEN_PLACEHOLDER__";
              };
            };
          };
        };

        # Inject gateway token from agenix into openclaw.json after HM writes it
        # Config is a nix store symlink — must copy to regular file, then sed
        home.activation.openclawInjectToken = lib.hm.dag.entryAfter [ "openclawConfigFiles" ] ''
          _token_file="${tokenPath}"
          _config="$HOME/.openclaw/openclaw.json"
          if [ -f "$_token_file" ] && [ -e "$_config" ]; then
            _real=$(readlink -f "$_config" 2>/dev/null || echo "$_config")
            cp "$_real" "$_config.tmp"
            _token=$(cat "$_token_file")
            /usr/bin/sed -i "" "s|__OPENCLAW_TOKEN_PLACEHOLDER__|$_token|g" "$_config.tmp"
            rm -f "$_config"
            mv "$_config.tmp" "$_config"
          fi
        '';
      };
  };
}
