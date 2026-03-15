{
  config,
  inputs,
  lib,
  pkgs,
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
        age.secrets.openclaw-gateway-token = {
          file = "${toString ../../../hosts}/shared/secrets/openclaw-gateway-token.age";
        };
        home.packages = [
          inputs.google-workspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];

        # Force-overwrite openclaw.json so HM never tries to back it up.
        # openclawInjectToken rewires this link target each rebuild; without
        # force=true HM may try to move the existing path to .bkup and collide.
        home.file.".openclaw/openclaw.json".force = true;

        programs.openclaw = {
          enable = true;
          # App installed via Homebrew — don't install via Nix
          installApp = false;

          instances.default = {
            enable = true;
            # No local gateway in remote mode — OpenClaw.app handles the connection
            launchd.enable = false;
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

        # Inject gateway token from agenix into a runtime config, then keep
        # ~/.openclaw/openclaw.json as a symlink for clean HM state.
        home.activation.openclawInjectToken = lib.hm.dag.entryAfter [ "openclawConfigFiles" ] ''
          _token_file="${tokenPath}"
          _config="$HOME/.openclaw/openclaw.json"
          _rendered="$HOME/.openclaw/openclaw.runtime.json"
          if [ -f "$_token_file" ] && [ -e "$_config" ]; then
            _real=$(readlink -f "$_config" 2>/dev/null || echo "$_config")
            cp "$_real" "$_rendered.tmp"
            _token=$(cat "$_token_file")
            /usr/bin/sed -i "" "s|__OPENCLAW_TOKEN_PLACEHOLDER__|$_token|g" "$_rendered.tmp"
            chmod 600 "$_rendered.tmp"
            mv "$_rendered.tmp" "$_rendered"
            ln -sfn "$_rendered" "$_config"
          fi
        '';
      };
  };
}
