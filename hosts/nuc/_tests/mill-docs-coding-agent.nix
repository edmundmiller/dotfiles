{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  service = cfg.systemd.services.mill-docs-coding-agent;
  acpxDir = "/var/lib/mill-docs-coding-agent/acpx";
  failures = builtins.filter (assertion: !assertion.test) [
    {
      test = builtins.elem "d ${acpxDir} 0700 emiller users -" cfg.systemd.tmpfiles.rules;
      msg = "Mill Docs coding agent must create its private acpx state directory.";
    }
    {
      test = service.environment.HOME == "/home/emiller";
      msg = "Mill Docs coding agent must preserve the user home used by SSH.";
    }
    {
      test =
        service.serviceConfig.ProtectHome == "read-only"
        && service.serviceConfig.BindPaths == [ "${acpxDir}:/home/emiller/.acpx" ];
      msg = "Mill Docs coding agent must bind writable acpx state into its protected home.";
    }
    {
      test = builtins.elem "/home/emiller/.omp/agent" service.serviceConfig.ReadWritePaths;
      msg = "Mill Docs coding agent must allow OMP to update its SQLite state.";
    }
    {
      test = builtins.elem "/home/emiller/.omp/run" service.serviceConfig.ReadWritePaths;
      msg = "Mill Docs coding agent must allow OMP to register daemon presence.";
    }
    {
      test = builtins.any (
        credential: pkgs.lib.hasPrefix "openai-api-key:" credential
      ) service.serviceConfig.LoadCredential;
      msg = "Mill Docs coding agent must load the OpenAI model credential.";
    }
  ];
in
pkgs.runCommand "nuc-mill-docs-coding-agent" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  ${builtins.concatStringsSep "\n" (map (failure: failure.msg) failures)}
  EOF
    exit 1
  fi
  touch "$out"
''
