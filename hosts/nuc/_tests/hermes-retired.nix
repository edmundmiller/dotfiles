{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  inherit (pkgs.lib)
    all
    filterAttrs
    hasInfix
    hasPrefix
    ;
  hermesUnit =
    name: hasPrefix "hermes-" name || hasPrefix "buzz-hermes-" name || hasPrefix "buzz-presence-" name;
  services = filterAttrs (name: _: hermesUnit name) cfg.systemd.services;
  timers = filterAttrs (name: _: hermesUnit name) cfg.systemd.timers;
  writers = filterAttrs (
    name: _:
    hasPrefix "hermes" name || hasPrefix "canonical-hermes-" name || name == "bootstrapLinearToken"
  ) cfg.system.activationScripts;
  ports = cfg.networking.firewall.interfaces.tailscale0.allowedTCPPorts;
  assertions = [
    {
      test = !cfg.modules.services.hermes.enable && !cfg.services.hermes-agent.enable;
      msg = "Both canonical and upstream Hermes modules must be disabled.";
    }
    {
      test = services != { } && all (unit: !unit.enable) (builtins.attrValues services);
      msg = "No Hermes gateway, dashboard, executor, secret materializer, or Buzz companion may be enabled.";
    }
    {
      test = timers != { } && all (unit: !unit.enable) (builtins.attrValues timers);
      msg = "No retired Hermes scheduler may start from a timer.";
    }
    {
      test = all (script: (script.text or "") == "") (builtins.attrValues writers);
      msg = "Activation must not rewrite retired Hermes state, configuration, or secrets.";
    }
    {
      test = all (port: !(builtins.elem port ports)) [
        8642
        8787
        9121
      ];
      msg = "Retirement must remove explicit Hermes tailnet firewall openings.";
    }
    {
      test =
        !(cfg.services.home-assistant.config.shell_command ? hermes_betty_good_morning_dj)
        && !(hasInfix "hermes_betty_good_morning_dj" (
          builtins.toJSON cfg.services.home-assistant.config.script.good_morning
        ))
        && all (
          rule: all (command: !(hasInfix "hermes-betty-good-morning-dj" command.command)) rule.commands
        ) cfg.security.sudo.extraRules;
      msg = "Home Assistant must not invoke Hermes or retain the DJ sudo permission.";
    }
    {
      test =
        cfg.modules.services.hass.enable
        && cfg.modules.services.music-assistant.enable
        && cfg.systemd.services.amp-nascent-manuscript-runner.enable
        && cfg.systemd.services.mill-docs-agents-tailscale-serve.enable;
      msg = "Hermes retirement must leave HA, Music Assistant, Amp, and Mill Docs enabled.";
    }
  ];
  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-hermes-retired"
  {
    passthru = { inherit assertions failures; };
  }
  ''
    ${
      if failures == [ ] then
        ""
      else
        ''
          cat >&2 <<'EOF'
          ${pkgs.lib.concatStringsSep "\n" (map (failure: failure.msg) failures)}
          EOF
          exit 1
        ''
    }
    mkdir -p "$out"
    echo "All ${toString (builtins.length assertions)} Hermes retirement assertions passed." > "$out/result"
  ''
