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
  cfg = config.modules.services.containers;
in
{
  options.modules.services.containers = {
    enable = mkBoolOpt false;

    provider = mkOption {
      type = types.enum [
        "orbstack"
        "podman"
      ];
      default = if isDarwin then "orbstack" else "podman";
      description = "Container provider: OrbStack on macOS or Podman on Linux.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # macOS keeps Docker-compatible commands supplied by OrbStack. Do not
    # install a second engine or CLI through Nix here.
    (optionalAttrs isDarwin (
      mkIf (cfg.provider == "orbstack") {
        env.DOCKER_CONTEXT = "orbstack";
        homebrew.casks = [ "orbstack" ];
      }
    ))

    # Linux uses Podman as the engine. The Docker CLI alias and API socket are
    # compatibility shims for Compose/Wrangler-style consumers; they do not
    # enable or start Docker Engine.
    (optionalAttrs (!isDarwin) (
      mkIf (cfg.provider == "podman") {
        user.packages = with pkgs; [
          podman
          unstable.docker-compose
        ];

        user.extraGroups = [ "podman" ];
        env.DOCKER_CONFIG = "$XDG_CONFIG_HOME/docker";
        env.DOCKER_HOST = "unix:///run/podman/podman.sock";

        modules.shell.zsh.rcFiles = [ "${configDir}/docker/aliases.zsh" ];

        virtualisation = {
          podman = {
            enable = true;
            dockerCompat = true;
            dockerSocket.enable = true;
            autoPrune.enable = true;
            defaultNetwork.settings.dns_enabled = true;
          };
          oci-containers.backend = "podman";
        };
      }
    ))

    {
      assertions = [
        {
          assertion = isDarwin -> cfg.provider == "orbstack";
          message = "Darwin container hosts must use OrbStack.";
        }
        {
          assertion = (!isDarwin) -> cfg.provider == "podman";
          message = "Linux container hosts must use Podman.";
        }
      ];
    }
  ]);
}
