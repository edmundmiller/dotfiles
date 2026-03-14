# modules/shell/agent-browser.nix
#
# agent-browser CLI module.
# Manages ~/.agent-browser/config.json with native-mode defaults and optional
# Helium (Kernel-compatible) remote browser connection settings.
{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.agentBrowser;

  managedConfig = {
    inherit (cfg)
      native
      contentBoundaries
      maxOutput
      ;
  }
  // optionalAttrs cfg.helium.enable {
    # Helium is Kernel-compatible; provider name in agent-browser is "kernel".
    provider = "kernel";
  }
  // optionalAttrs (cfg.helium.cdpUrl != null) {
    cdp = cfg.helium.cdpUrl;
  };

  finalConfig = managedConfig // cfg.extraConfig;
in
{
  options.modules.shell.agentBrowser = with types; {
    enable = mkBoolOpt false;

    installWithHomebrew = mkBoolOpt false;

    native = mkBoolOpt true;

    contentBoundaries = mkBoolOpt true;

    maxOutput = mkOption {
      type = types.int;
      default = 50000;
      description = "Max text output chars before truncation.";
    };

    helium = {
      enable = mkBoolOpt false;

      cdpUrl = mkOption {
        type = nullOr str;
        default = null;
        description = ''
          Optional Helium CDP WebSocket URL (wss://...).
          When set, written to config as "cdp".
        '';
      };

      kernelEndpoint = mkOption {
        type = nullOr str;
        default = null;
        description = ''
          Optional Kernel-compatible API endpoint for Helium.
          Export KERNEL_API_KEY separately via your secret manager.
        '';
      };
    };

    extraConfig = mkOption {
      type = attrsOf anything;
      default = { };
      description = "Additional agent-browser config.json keys merged last.";
    };
  };

  config = mkIf cfg.enable (
    mkMerge (
      [
        {
          home-manager.users.${config.user.name}.home.file.".agent-browser/config.json".text =
            builtins.toJSON finalConfig;
        }

        (mkIf (cfg.helium.enable && cfg.helium.kernelEndpoint != null) {
          home-manager.users.${config.user.name}.home.sessionVariables.KERNEL_ENDPOINT =
            cfg.helium.kernelEndpoint;
        })
      ]
      ++ optionals isDarwin [
        (mkIf cfg.installWithHomebrew {
          homebrew.brews = [ "agent-browser" ];
        })
      ]
    )
  );
}
