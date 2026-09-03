# Pure Nix/build test: the Git dirt audit must never fail the sync dead-man-switch.
# Regression guard for false "DOWN | nuc/obsidian-sync" alerts caused by the
# dirt audit reusing the obsidian-sync healthchecks.io ping URL.
{
  nixosConfig,
  pkgs,
}:
let
  nuc = nixosConfig.config;
  dirtAudit = nuc.systemd.services.obsidian-vault-git-dirt-check.serviceConfig.ExecStart;
in
pkgs.runCommand "obsidian-dirt-audit-healthcheck-decoupled"
  {
    passthru = { inherit dirtAudit; };
  }
  ''
    if grep -q "hc-ping.com" "${dirtAudit}"; then
      echo "NUC Git dirt audit must not ping the obsidian-sync healthcheck" >&2
      echo "dirtAudit=${dirtAudit}" >&2
      exit 1
    fi
    mkdir -p "$out"
    echo "dirt audit healthcheck decoupling verified: ${dirtAudit}" > "$out/result"
  ''