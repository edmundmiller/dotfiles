# Pure Nix eval test: Linux hosts use Podman without enabling Docker Engine.
{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  containers = cfg.modules.services.containers;
  podman = cfg.virtualisation.podman;
  smoke = cfg.systemd.services.hermes-runtime-smoke;
  composeEnvironment = service: service.environment.DOCKER_HOST or null;
  nucHostSource = builtins.readFile ../default.nix;
  inherit (builtins) elem filter length;
  inherit (pkgs.lib.strings) hasInfix;

  assertions = [
    {
      test = containers.enable && containers.provider == "podman";
      msg = "NUC must select Podman as its container provider.";
    }
    {
      test = podman.enable && podman.dockerCompat && podman.dockerSocket.enable;
      msg = "NUC must expose only Podman's Docker-compatible CLI and API socket.";
    }
    {
      test = cfg.virtualisation.docker.enable == false;
      msg = "NUC must not enable Docker Engine.";
    }
    {
      test = cfg.virtualisation.oci-containers.backend == "podman";
      msg = "OCI containers must use Podman on the NUC.";
    }
    {
      test = elem "podman.socket" smoke.after && !(elem "docker.service" smoke.after);
      msg = "Hermes runtime smoke must wait for Podman, not Docker Engine.";
    }
    {
      test = hasInfix "pkgs.podman" nucHostSource && !(hasInfix "pkgs.docker" nucHostSource);
      msg = "Scintillate refresh must use Podman for container cleanup.";
    }
    {
      test =
        composeEnvironment cfg.systemd.services.latitude-compose == "unix:///run/podman/podman.sock"
        && composeEnvironment cfg.systemd.services.sparkyfitness == "unix:///run/podman/podman.sock"
        && composeEnvironment cfg.systemd.services.open-wearables == "unix:///run/podman/podman.sock";
      msg = "Podman-backed Compose units must target Podman's API socket explicitly.";
    }
  ];
  failures = filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-container-runtime-assertions" { passthru = { inherit assertions failures; }; }
  ''
    if [ ${toString (length failures)} -ne 0 ]; then
      echo "${toString (length failures)} NUC container runtime assertions failed" >&2
      exit 1
    fi
    mkdir -p "$out"
    echo "All NUC container runtime assertions passed." > "$out/result"
  ''
