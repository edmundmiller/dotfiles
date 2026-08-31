{
  nixosConfig,
  pkgs,
  buzzBindings,
}:
let
  cfg = nixosConfig.config;
  service = cfg.systemd.services.buzz-mill-docs-flue;
  failures = builtins.filter (assertion: !assertion.test) [
    {
      test = service.environment.BUZZ_FLUE_URL == "https://mill-docs-agents.cinnamon-rooster.ts.net";
      msg = "Mill Docs Flue bridge must use the tailnet Worker endpoint.";
    }
    {
      test =
        service.environment.BUZZ_FLUE_AGENT_PUBKEY == buzzBindings.identities.millDocsWorker.pubkey
        && service.environment.BUZZ_FLUE_ALLOWED_AUTHORS == buzzBindings.identities.edmund.pubkey
        && service.environment.BUZZ_FLUE_CHANNEL_IDS == buzzBindings.channels.mill-docs.id
        && service.environment.BUZZ_FLUE_DM_CHANNEL_IDS == "";
      msg = "Mill Docs Flue bridge must preserve the existing identity, owner-only policy, and forum route.";
    }
    {
      test =
        service.serviceConfig.EnvironmentFile == [
          cfg.age.secrets.buzz-mill-docs-agent-env.path
          cfg.age.secrets.buzz-mill-docs-flue-env.path
        ]
        && pkgs.lib.hasSuffix "/bin/node scripts/buzz-flue-bridge.ts" service.serviceConfig.ExecStart;
      msg = "Mill Docs Flue bridge must load isolated identity and bridge secrets with the Node bridge entrypoint.";
    }
    {
      test =
        builtins.elem "buzz-mill-docs-codex.service" service.conflicts
        && cfg.systemd.services.buzz-mill-docs-codex.wantedBy == [ ];
      msg = "Flue bridge must replace, not duplicate, the existing Mill Docs ACP consumer.";
    }
  ];
in
pkgs.runCommand "nuc-buzz-mill-docs-flue-runtime" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  ${builtins.concatStringsSep "\n" (map (failure: failure.msg) failures)}
  EOF
    exit 1
  fi
  touch "$out"
''
