{ config, pkgs, ... }:
{
  user.packages = [ pkgs.my.agento11y ];

  modules.agents.pi.extraPackages = [ "npm:@grafana/agento11y-pi@0.24.0" ];

  home-manager.users.${config.user.name} =
    { lib, ... }:
    {
      home.activation.agento11y = lib.hm.dag.entryAfter [ "codex-config-bootstrap" ] ''
        (
          set -eu
          umask 077
          config_dir="$HOME/.config/agento11y"
          mkdir -p "$config_dir"
          tmp="$(mktemp "$config_dir/config.env.XXXXXX")"
          trap 'rm -f "$tmp"' EXIT
          export OP_BIOMETRIC_UNLOCK_ENABLED="''${OP_BIOMETRIC_UNLOCK_ENABLED:-true}"
          ${pkgs._1password-cli}/bin/op inject --force \
            --in-file ${../../config/agento11y/config.env.tpl} --out-file "$tmp"
          mv "$tmp" "$config_dir/config.env"

          ${pkgs.llm-agents.codex}/bin/codex plugin marketplace add grafana/agento11y \
            --ref 733c5ad8675dacbadab529bb24625ef25c3b8508 --json
          ${pkgs.llm-agents.codex}/bin/codex plugin add agento11y-codex@agento11y --json
          ${pkgs.my.agento11y}/bin/agento11y agents reconcile --agents cursor --json
        )
      '';
    };
}
