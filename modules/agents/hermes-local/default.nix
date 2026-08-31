{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.agents.hermes-local;
  agentPackages = inputs.agents-workspace.packages.${pkgs.system};
  hermesPackage = import ./_package.nix { inherit inputs pkgs; };
  upstreamLauncher = name: agentPackages.${name + "-hermes"};
  launcher =
    name:
    pkgs.writeShellScriptBin "${name}-hermes" ''
      # Nix Bash 5.3 can deadlock while materializing the upstream launcher's
      # embedded policy heredoc on Darwin. The system Bash completes it safely.
      exec /bin/bash ${upstreamLauncher name}/bin/${name}-hermes "$@"
    '';
  workspaceRevision = inputs.agents-workspace.rev or "unknown";
  manifest = pkgs.writeText "hermes-local-manifest.json" (
    builtins.toJSON {
      agentsWorkspaceRevision = workspaceRevision;
      hermes = "${hermesPackage}/bin/hermes";
      launchers = lib.genAttrs cfg.profiles (name: "${launcher name}/bin/${name}-hermes");
      inherit (cfg) profiles;
    }
  );
in
{
  options.modules.agents.hermes-local = {
    enable = lib.mkEnableOption "Nix-managed local Hermes runtime and canonical profile launchers";

    profiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Canonical agents-workspace profiles to install as Hermes launchers.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "modules.agents.hermes-local is Darwin-only; use the Hermes NixOS module on Linux.";
      }
    ];

    user.packages = [ hermesPackage ] ++ map launcher cfg.profiles;

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.file.".config/hermes-local/manifest.json".source = manifest;

        home.activation.hermes-local-legacy-cleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          legacy="$HOME/.local/bin/hermes"
          if [ -L "$legacy" ]; then
            target="$(${pkgs.coreutils}/bin/readlink "$legacy" 2>/dev/null || true)"
            case "$target" in
              *'.hermes/hermes-agent/venv/bin/hermes'*)
                ${pkgs.coreutils}/bin/rm -f "$legacy"
                ;;
            esac
          elif [ -f "$legacy" ] && ${pkgs.gnugrep}/bin/grep -qF '.hermes/hermes-agent/venv/bin/hermes' "$legacy"; then
            ${pkgs.coreutils}/bin/rm -f "$legacy"
          fi
        '';
      };
  };
}
