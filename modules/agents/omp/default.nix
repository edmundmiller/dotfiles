{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents.omp;
  inherit (config.dotfiles) configDir;
  ompConfigDir = "${config.user.home}/.omp";
  ompAgentDir = "${ompConfigDir}/agent";
  ompPackage = pkgs.stdenvNoCC.mkDerivation {
    name = "${cfg.package.pname or "omp"}-isolated";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall

      cp -a ${cfg.package} "$out"
      chmod -R u+w "$out"

      if [ -x "$out/lib/omp/omp" ] && [ -x /usr/bin/codesign ]; then
        /usr/bin/codesign -f -s - "$out/lib/omp/omp"
      fi

      rm -f "$out/bin/omp"
      makeWrapper "$out/lib/omp/omp" "$out/bin/omp" \
        --set PI_SKIP_VERSION_CHECK 1 \
        --set PI_CONFIG_DIR ${lib.escapeShellArg ompConfigDir} \
        --set PI_CODING_AGENT_DIR ${lib.escapeShellArg ompAgentDir} \
        --set PI_PERMISSION_SYSTEM_CONFIG_PATH ${lib.escapeShellArg "${ompAgentDir}/extensions/pi-permission-system/config.json"}${
          lib.optionalString (
            cfg.smolModel != null
          ) " --set PI_SMOL_MODEL ${lib.escapeShellArg cfg.smolModel}"
        }

      runHook postInstall
    '';
    meta = cfg.package.meta or { };
  };
in
{
  options.modules.agents.omp = {
    enable = mkBoolOpt false;
    package = mkOption {
      type = types.package;
      default = pkgs.llm-agents.omp;
      description = "OMP package to install.";
    };
    smolModel = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "xai-oauth/grok-composer-2.5-fast";
      description = ''
        Per-host override for the smol/fast model role, injected as
        PI_SMOL_MODEL. Also drives the commit role, which falls back to smol
        when modelRoles.commit is unset. Null keeps whatever modelRoles.smol is
        set in the mutable ~/.omp/agent/config.yml. default/slow/plan are
        intentionally not exposed here — they live in the mutable config and
        stay identical across hosts.
      '';
    };
  };

  config = mkIf cfg.enable {
    user.packages = [
      (lib.hiPrio ompPackage)
    ];

    home.file.".omp/agent/config.yml" = {
      source = "${configDir}/omp/config.yml";
      force = true;
    };

    home.file.".omp/agent/extensions/pi-permission-system/config.json".source =
      "${configDir}/pi/pi-permission-system.jsonc";
  };
}
