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
        --set PI_PERMISSION_SYSTEM_CONFIG_PATH ${lib.escapeShellArg "${ompAgentDir}/extensions/pi-permission-system/config.json"}

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
  };

  config = mkIf cfg.enable {
    user.packages = [
      (lib.hiPrio ompPackage)
    ];

    home.file.".omp/agent/extensions/pi-permission-system/config.json".source =
      "${configDir}/pi/pi-permission-system.jsonc";
  };
}
