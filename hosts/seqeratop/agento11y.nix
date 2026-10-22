{ config, pkgs, ... }:
{
  user.packages = [ pkgs.my.agento11y ];

  modules.agents.pi.extraPackages = [ "npm:@grafana/agento11y-pi@0.25.0" ];

  home-manager.users.${config.user.name} =
    { lib, ... }:
    {
      home.activation.agento11y =
        lib.hm.dag.entryAfter
          [
            "codex-config-bootstrap"
            # claude-settings-bootstrap rewrites ~/.claude/settings.json from the
            # repo template. It keeps hooks and plugin entries that are not in
            # the template. Install still runs after that rewrite. agento11y
            # claude install returns already_installed when
            # installed_plugins.json already lists the plugin and does not
            # write enabledPlugins, so enable the plugin explicitly afterward.
            "claude-settings-bootstrap"
          ]
          ''
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
              # Claude Code has no --ref pin for marketplaces; agento11y's own
              # installer is the supported non-interactive path and wires the plugin
              # to this pinned binary.
              PATH="${pkgs.llm-agents.claude-code}/bin:$PATH" \
                ${pkgs.my.agento11y}/bin/agento11y claude install --json
              if ! ${pkgs.llm-agents.claude-code}/bin/claude plugin enable \
                agento11y-claude-code@agento11y; then
                echo "ERROR: failed to enable Claude Code plugin agento11y-claude-code@agento11y" >&2
                exit 1
              fi

              ${pkgs.my.agento11y}/bin/agento11y agents reconcile --agents cursor --json
            )
          '';
    };
}
