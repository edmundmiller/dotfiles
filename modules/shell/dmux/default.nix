# dmux shell module: installs dmux wrapper + config for pi/opencode inference fallback.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.dmux;
in
{
  options.modules.shell.dmux = {
    enable = mkBoolOpt false;
    autoInstallUpstream = mkBoolOpt true;
    npmPackage = mkOption {
      type = types.str;
      default = "dmux@5.4.0";
      description = "Upstream dmux npm package to install globally";
    };
    provider = mkOption {
      type = types.enum [
        "auto"
        "opencode"
        "pi"
        "openrouter"
      ];
      default = "pi";
      description = "Inference provider mode for dmux AI shim";
    };
    providerOrder = mkOption {
      type = types.listOf (
        types.enum [
          "opencode"
          "pi"
          "openrouter"
        ]
      );
      default = [
        "opencode"
        "pi"
        "openrouter"
      ];
      description = "Provider fallback order when provider=auto";
    };
    opencodeAttach = mkOption {
      type = types.str;
      default = "";
      description = "Optional opencode server URL (used with opencode run --attach)";
    };
    opencodeModel = mkOption {
      type = types.str;
      default = "";
      description = "Optional opencode model override for dmux inference";
    };
    opencodeAgent = mkOption {
      type = types.str;
      default = "";
      description = "Optional opencode agent override for dmux inference";
    };
    piModel = mkOption {
      type = types.str;
      default = "";
      description = "Optional pi model override for dmux inference";
    };
    timeoutMs = mkOption {
      type = types.int;
      default = 20000;
      description = "Inference timeout per dmux AI request";
    };
  };

  config = mkIf cfg.enable {
    user.packages = [ pkgs.my.dmux ];

    environment.shellAliases = {
      dmux = "${pkgs.my.dmux}/bin/dmux";
    };

    modules.shell.zsh.envInit = ''
      export PATH="${pkgs.my.dmux}/bin:$PATH"
    '';

    env = {
      # Put wrapper dmux before npm global bin so wrapper is always used.
      PATH = mkBefore [ "${pkgs.my.dmux}/bin" ];
      DMUX_AI_PROVIDER = cfg.provider;
      DMUX_AI_PROVIDER_ORDER = concatStringsSep "," cfg.providerOrder;
      DMUX_AI_TIMEOUT_MS = toString cfg.timeoutMs;
    }
    // optionalAttrs (cfg.opencodeAttach != "") { DMUX_OPENCODE_ATTACH = cfg.opencodeAttach; }
    // optionalAttrs (cfg.opencodeModel != "") { DMUX_OPENCODE_MODEL = cfg.opencodeModel; }
    // optionalAttrs (cfg.opencodeAgent != "") { DMUX_OPENCODE_AGENT = cfg.opencodeAgent; }
    // optionalAttrs (cfg.piModel != "") { DMUX_PI_MODEL = cfg.piModel; };

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.activation.install-dmux-upstream = lib.hm.dag.entryAfter [ "writeBoundary" ] (
          lib.optionalString cfg.autoInstallUpstream ''
            npm_bin="${pkgs.nodejs}/bin/npm"
            pnpm_bin="${pkgs.pnpm}/bin/pnpm"

            cache_home="''${XDG_CACHE_HOME:-$HOME/.cache}"
            data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
            dmux_cache_bin="$cache_home/npm/bin/dmux"
            dmux_data_bin="$data_home/npm/bin/dmux"

            if [ ! -x "$dmux_cache_bin" ] && [ ! -x "$dmux_data_bin" ]; then
              if [ -x "$pnpm_bin" ]; then
                package_manager="$pnpm_bin"
              else
                package_manager="$npm_bin"
              fi

              if [ -x "$package_manager" ]; then
                echo "Installing upstream dmux (${cfg.npmPackage})..."
                "$package_manager" install -g ${cfg.npmPackage} \
                  || echo "Warning: failed to install upstream dmux; wrapper will require manual install."
              fi
            fi
          ''
        );
      };
  };
}
