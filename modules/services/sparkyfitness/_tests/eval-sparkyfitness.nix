# Pure Nix eval test: keep SparkyFitness private, recoverable, and supervised.
{ nixosConfig, pkgs }:
let
  inherit (builtins)
    concatStringsSep
    elem
    filter
    length
    ;
  inherit (pkgs.lib.strings) hasInfix;

  cfg = nixosConfig.config;
  compose = cfg.modules.services.sparkyfitness.generatedCompose or "";
  service = cfg.systemd.services.sparkyfitness or { };
  execStart = service.serviceConfig.ExecStart or "";
  execStop = service.serviceConfig.ExecStop or "";
  serve = cfg.systemd.services.sparkyfitness-tailscale-serve or { };
  serveExecStart = serve.serviceConfig.ExecStart or "";
  backup = cfg.services.restic.backups.sparkyfitness-state or { };
  firewallPorts = cfg.networking.firewall.allowedTCPPorts or [ ];
  tmpfilesRules = cfg.systemd.tmpfiles.rules or [ ];

  assertions = [
    {
      test = cfg.modules.services.sparkyfitness.enable or false;
      msg = "SparkyFitness must be enabled on the NUC";
    }
    {
      test =
        hasInfix "postgres:18.3-alpine@sha256:54451ecb8ab38c24c3ec123f2fd501303a3a1856a5c66e98cecf2460d5e1e9d7" compose
        && hasInfix "codewithcj/sparkyfitness_server:v0.17.3@sha256:6aa7d9832324ea403be144a26398a82afbf04abbb4da89f9d04ba61838516b3f" compose
        && hasInfix "codewithcj/sparkyfitness:v0.17.3@sha256:46d90e46bd87312fcbbbb05036d99e4cb1c821e928b0516ee727de4c3c90752b" compose;
      msg = "SparkyFitness must use the reviewed image digests";
    }
    {
      test = hasInfix ''- "127.0.0.1:3004:80"'' compose;
      msg = "SparkyFitness must publish only its frontend on loopback";
    }
    {
      test =
        hasInfix "/var/lib/sparkyfitness/postgresql:/var/lib/postgresql" compose
        && hasInfix "/var/lib/sparkyfitness/backup:/app/SparkyFitnessServer/backup" compose
        && hasInfix "/var/lib/sparkyfitness/uploads:/app/SparkyFitnessServer/uploads" compose;
      msg = "SparkyFitness must keep database, backups, and uploads on durable mounts";
    }
    {
      test =
        hasInfix "SPARKY_FITNESS_DB_HOST: sparkyfitness-db" compose
        && hasInfix "SPARKY_FITNESS_SERVER_HOST: sparkyfitness-server" compose;
      msg = "SparkyFitness services must use private Compose DNS";
    }
    {
      test =
        hasInfix "sparkyfitness-db:\n        condition: service_healthy" compose
        && hasInfix "sparkyfitness-server:\n        condition: service_healthy" compose;
      msg = "SparkyFitness dependencies must wait for healthy services";
    }
    {
      test = hasInfix "--env-file /run/agenix/sparkyfitness-env" execStart;
      msg = "SparkyFitness must load its agenix environment file";
    }
    {
      test = hasInfix "up -d --remove-orphans --wait --wait-timeout 180" execStart;
      msg = "SparkyFitness startup must wait for healthy containers";
    }
    {
      test = hasInfix "down --timeout 60" execStop;
      msg = "SparkyFitness shutdown must stop its Compose stack cleanly";
    }
    {
      test = hasInfix "--service=svc:sparkyfitness" serveExecStart;
      msg = "SparkyFitness Tailscale Serve must advertise svc:sparkyfitness";
    }
    {
      test = hasInfix "http://127.0.0.1:3004" serveExecStart;
      msg = "SparkyFitness Tailscale Serve must proxy to loopback port 3004";
    }
    {
      test = !elem 3004 firewallPorts;
      msg = "SparkyFitness port 3004 must not be opened in the firewall";
    }
    {
      test = elem "d /var/lib/sparkyfitness/postgresql 0750 70 70 -" tmpfilesRules;
      msg = "SparkyFitness PostgreSQL state must be writable by the Alpine postgres user";
    }
    {
      test = elem "/var/lib/sparkyfitness" (backup.paths or [ ]);
      msg = "SparkyFitness backup must include /var/lib/sparkyfitness";
    }
    {
      test = (backup.pruneOpts or null) == [ ];
      msg = "SparkyFitness backup must not prune while the service is stopped";
    }
    {
      test = hasInfix "stop sparkyfitness.service" (backup.backupPrepareCommand or "");
      msg = "SparkyFitness backup must stop the stack before snapshotting";
    }
    {
      test = hasInfix "start sparkyfitness.service" (backup.backupCleanupCommand or "");
      msg = "SparkyFitness backup must restart the stack after snapshotting";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;
  resultText =
    if failures == [ ] then
      "All ${toString (length assertions)} SparkyFitness assertions passed."
    else
      concatStringsSep "\n" (
        [ "${toString (length failures)}/${toString (length assertions)} SparkyFitness assertions failed:" ]
        ++ map (assertion: "  FAIL: ${assertion.msg}") failures
      );
in
pkgs.runCommand "sparkyfitness-assertions"
  {
    passthru = { inherit assertions failures; };
  }
  ''
    ${
      if failures == [ ] then
        ''
          echo "${resultText}"
          mkdir -p $out
          echo "${resultText}" > $out/result
        ''
      else
        ''
          echo "${resultText}" >&2
          exit 1
        ''
    }
  ''
