{ config, pkgs, ... }:
{
  # The former installer wrote mutable files outside Home Manager ownership.
  # Run even when the formerly integrated agent modules are disabled.
  home-manager.users.${config.user.name} =
    { lib, ... }:
    {
      home.activation.retired-moshi-cleanup =
        lib.hm.dag.entryAfter
          [
            "writeBoundary"
            "claude-settings-bootstrap"
            "codex-config-bootstrap"
            "herdr-agent-integrations"
          ]
          ''
            ${pkgs.python3}/bin/python3 ${./cleanup.py} "$HOME"
          '';
    };
}
