{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Cadu owns plugin installation, pairing, and grants. Nix owns enablement
  # because Hermes refuses config writes when its .managed marker is present.
  caduPlugins = [
    "cadu-rich-cards"
    "cadu-device"
    "cadu-secrets-vault"
    "hermes-browser-stream"
    "hermes-push"
  ];
  agents = import (inputs.agents-workspace + /agents/registry.nix) { inherit lib; };
  yamlPython = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  sharedHome = "/var/lib/hermes/.hermes";
  enableDashboardPlugins = pkgs.writeShellScript "hermes-cadu-dashboard-enable" ''
    set -eu
    ${yamlPython}/bin/python3 - "$@" <<'PY'
    import os
    from pathlib import Path
    import sys
    import tempfile
    import yaml

    home = Path(sys.argv[1])
    path = home / "config.yaml"
    config = yaml.safe_load(path.read_text()) or {}
    plugins = config.setdefault("plugins", {})
    enabled = plugins.setdefault("enabled", [])
    for name in sys.argv[2:]:
        if not (home / "plugins" / name / "plugin.yaml").is_file():
            continue
        if name not in enabled:
            enabled.append(name)
    with tempfile.NamedTemporaryFile(mode="w", dir=home, delete=False) as output:
        yaml.safe_dump(config, output, sort_keys=False)
        temporary = output.name
    os.replace(temporary, path)
    PY
  '';
in
{
  modules.services.hermes.agents =
    lib.genAttrs
      [
        "amosburton"
        "anne"
        "betty"
        "finn"
        "orchestrator"
        "scintillate"
      ]
      (name: {
        settings.plugins.enabled = lib.unique (
          (agents.${name}.hermes.settings.plugins.enabled or [ ]) ++ caduPlugins
        );
      });

  systemd.services.hermes-scintillate-desktop-dashboard.serviceConfig.ExecStartPre = [
    "${enableDashboardPlugins} ${lib.escapeShellArg sharedHome} ${lib.escapeShellArgs caduPlugins}"
  ];
}
