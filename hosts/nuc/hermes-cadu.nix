{
  config,
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
    "cadu-mail"
    "cadu-secrets-vault"
    "hermes-browser-stream"
    "hermes-push"
  ];
  minimumHermesVersion = "0.21.3";
  profiles = [
    "amosburton"
    "anne"
    "betty"
    "finn"
    "orchestrator"
    "scintillate"
  ];
  disabledPlugins = [
    "buzz-platform"
    "slack-platform"
  ];
  agents = import (inputs.agents-workspace + /agents/registry.nix) { inherit lib; };
  hermesVersion = config.services.hermes-agent.package.passthru.hermesVersion or "0";
  yamlPython = pkgs.python3.withPackages (ps: [
    ps.packaging
    ps.pyyaml
  ]);
  sharedHome = "/var/lib/hermes/.hermes";
  enableDashboardPlugins = pkgs.writeShellScript "hermes-cadu-dashboard-enable" ''
    set -eu
    ${yamlPython}/bin/python3 - "$@" <<'PY'
    import os
    from pathlib import Path
    import sys
    import tempfile
    from packaging.specifiers import InvalidSpecifier, SpecifierSet
    from packaging.version import InvalidVersion, Version
    import yaml

    home = Path(sys.argv[1])
    hermes_version = sys.argv[2]
    path = home / "config.yaml"
    config = yaml.safe_load(path.read_text()) or {}
    plugins = config.setdefault("plugins", {})
    enabled = plugins.setdefault("enabled", [])
    for name in sys.argv[3:]:
        manifest_path = home / "plugins" / name / "plugin.yaml"
        if not manifest_path.is_file():
            continue
        manifest = yaml.safe_load(manifest_path.read_text()) or {}
        requirement = str(manifest.get("requires_hermes", "")).strip()
        if requirement:
            clauses = [clause.strip() for clause in requirement.split(",")]
            normalized = ",".join(
                clause if clause.startswith((">", "<", "=", "!", "~")) else f">={clause}"
                for clause in clauses
                if clause
            )
            try:
                compatible = Version(hermes_version) in SpecifierSet(normalized)
            except (InvalidSpecifier, InvalidVersion) as error:
                print(f"skipping {name}: invalid requires_hermes {requirement}: {error}", file=sys.stderr)
                compatible = False
            if not compatible:
                print(
                    f"skipping {name}: requires hermes {requirement}, running {hermes_version}",
                    file=sys.stderr,
                )
                enabled[:] = [enabled_name for enabled_name in enabled if enabled_name != name]
                continue
        if name not in enabled:
            enabled.append(name)
    # Keep installed code and credentials, but do not load retired transports.
    disabled = plugins.setdefault("disabled", [])
    for name in ("buzz-platform", "slack-platform"):
        if name not in disabled:
            disabled.append(name)
    plugins["enabled"] = [name for name in enabled if name not in disabled]
    for settings in (config, config.setdefault("gateway", {})):
        platforms = settings.setdefault("platforms", {})
        for name in ("buzz", "slack"):
            platforms.setdefault(name, {})["enabled"] = False
    # Native vault availability must not auto-grant external password managers.
    for name in ("onepassword", "bitwarden"):
        config.setdefault("vault", {}).setdefault(name, {})["enabled"] = False
    with tempfile.NamedTemporaryFile(mode="w", dir=home, delete=False) as output:
        yaml.safe_dump(config, output, sort_keys=False)
        temporary = output.name
    os.replace(temporary, path)
    PY
  '';
in
{
  assertions = [
    {
      assertion = lib.versionAtLeast hermesVersion minimumHermesVersion;
      message = "The NUC Cadu plugin set requires Hermes >=${minimumHermesVersion}.";
    }
  ];

  modules.services.hermes.agents = lib.genAttrs profiles (name: {
    settings = {
      plugins.enabled = lib.filter (plugin: !(builtins.elem plugin disabledPlugins)) (
        lib.unique ((agents.${name}.hermes.settings.plugins.enabled or [ ]) ++ caduPlugins)
      );
      plugins.disabled = lib.unique (
        (agents.${name}.hermes.settings.plugins.disabled or [ ]) ++ disabledPlugins
      );
      gateway.platforms.buzz.enabled = lib.mkForce false;
      gateway.platforms.slack.enabled = lib.mkForce false;
      platforms.buzz.enabled = lib.mkForce false;
      platforms.slack.enabled = lib.mkForce false;
      vault.onepassword.enabled = false;
      vault.bitwarden.enabled = false;
    };
  });

  systemd.services = lib.mkMerge [
    # A configuration switch must not SIGTERM an in-flight turn. Hermes treats
    # SIGUSR1 as a drain-aware restart request and its supervisor relaunches the
    # gateway against the new package and configuration.
    (lib.genAttrs (map (name: "hermes-gateway-${name}") profiles) (_: {
      reloadIfChanged = true;
      serviceConfig.ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";
    }))
    (lib.genAttrs (map (name: "buzz-presence-${name}") profiles) (_: {
      enable = lib.mkForce false;
    }))
    (lib.genAttrs (map (name: "buzz-hermes-${name}") profiles) (_: {
      enable = lib.mkForce false;
    }))
    {
      hermes-scintillate-desktop-dashboard.serviceConfig.ExecStartPre = [
        "${enableDashboardPlugins} ${lib.escapeShellArg sharedHome} ${lib.escapeShellArg hermesVersion} ${lib.escapeShellArgs caduPlugins}"
      ];
    }
  ];

  # The unpatched gateway owns its native scheduler. Do not run a second
  # systemd ticker after removing the custom gateway_ticker ownership guard.
  systemd.timers =
    lib.genAttrs
      (map (name: "hermes-${name}-cron-tick") [
        "amosburton"
        "betty"
        "scintillate"
      ])
      (_: {
        enable = lib.mkForce false;
      });
}
