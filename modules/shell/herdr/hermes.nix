{
  config,
  options,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
let
  cfg = config.modules.shell.herdr;

  hasHermesAgentOption =
    !isDarwin
    && options ? services
    && options.services ? "hermes-agent"
    && options.services."hermes-agent" ? profiles;

  yamlPython = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);

  launchPath = concatStringsSep ":" [
    "/etc/profiles/per-user/${config.user.name}/bin"
    "/run/current-system/sw/bin"
    "${config.user.home}/.nix-profile/bin"
    "${config.user.home}/.pi/agent/bin"
    "${config.user.home}/.bun/bin"
    "${config.user.home}/.local/bin"
    "${config.user.home}/.pixi/bin"
    "${config.user.home}/.cargo/bin"
    config.dotfiles.binDir
    "/nix/var/nix/profiles/default/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];

  yamlRepairScript = pkgs.writeText "herdr-hermes-yaml-fix.py" ''
    import pathlib
    import sys
    import yaml

    path = pathlib.Path(sys.argv[1])
    if path.exists():
        lines = path.read_text(encoding="utf-8").splitlines()
        fixed = []
        in_plugins = False
        in_enabled = False
        changed = False
        for line in lines:
            stripped = line.strip()
            if line and not line.startswith(" ") and stripped.endswith(":"):
                in_plugins = stripped == "plugins:"
                in_enabled = False
            elif in_plugins and line.startswith("  ") and not line.startswith("    ") and stripped.endswith(":"):
                in_enabled = stripped == "enabled:"
            elif in_plugins and in_enabled and line.startswith("  - "):
                line = "  " + line
                changed = True
            fixed.append(line)
        if changed:
            path.write_text("\n".join(fixed) + "\n", encoding="utf-8")
        with path.open(encoding="utf-8") as f:
            yaml.safe_load(f)
  '';
in
{
  config = mkIf cfg.enable {
    system.activationScripts.herdr-hermes-agent-integrations =
      mkIf
        (
          hasHermesAgentOption
          && cfg.integrations.hermes.enable
          && (config.services.hermes-agent.enable or false)
          && config.services.hermes-agent.profiles != { }
        )
        {
          deps = [ "hermes-profiles-setup" ];
          text = concatStringsSep "\n" (
            mapAttrsToList (
              name: profile:
              let
                hermesHome = "${profile.stateDir}/.hermes";
              in
              ''
                echo "herdr: installing Hermes Agent integration for profile ${name}"
                if [ -d ${escapeShellArg hermesHome} ]; then
                  PATH=${escapeShellArg launchPath}:$PATH \
                    HOME=${escapeShellArg profile.stateDir} \
                    HERMES_HOME=${escapeShellArg hermesHome} \
                    ${escapeShellArg cfg.command} integration install hermes >/dev/null

                  # Validate the whole Hermes config file after Herdr mutates it.
                  # Herdr's Hermes integration installer can leave existing
                  # plugins.enabled entries at the wrong indentation, producing
                  # invalid YAML like:
                  #   plugins:
                  #     enabled:
                  #       - herdr-agent-state
                  #     - evo
                  # Repair that known shape immediately, then parse the entire
                  # file (check-yaml style) so any remaining YAML error fails
                  # activation with a precise parser message instead of leaving
                  # a broken runtime config behind.
                  ${yamlPython}/bin/python3 ${yamlRepairScript} ${escapeShellArg "${hermesHome}/config.yaml"}

                  chown -R ${config.services.hermes-agent.user}:${config.services.hermes-agent.group} \
                    ${escapeShellArg "${hermesHome}/plugins/herdr-agent-state"} \
                    ${escapeShellArg "${hermesHome}/config.yaml"} 2>/dev/null || true
                  chmod -R u+rwX,go-rwx \
                    ${escapeShellArg "${hermesHome}/plugins/herdr-agent-state"} 2>/dev/null || true
                fi
              ''
            ) config.services.hermes-agent.profiles
          );
        };
  };
}
