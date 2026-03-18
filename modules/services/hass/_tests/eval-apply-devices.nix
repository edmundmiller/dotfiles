# Pure Nix eval test: assert hass-apply-devices is self-sufficient during deploys.
#
# Checks that the service no longer depends on /var/lib/hass/devices.yaml already
# existing before startup, and that we don't install nested tmpfiles entries inside
# HA's state dir that trip systemd's unsafe-path checks.
{ nixosConfig, pkgs }:
let
  inherit (builtins)
    attrNames
    concatStringsSep
    elem
    filter
    length
    ;
  inherit (pkgs.lib.strings) hasInfix;

  haConfigDir = nixosConfig.config.services.home-assistant.configDir;
  hassTmpfiles = nixosConfig.config.systemd.tmpfiles.settings."10-hass-nix-yaml" or { };
  devicesTmpfile = hassTmpfiles."${haConfigDir}/devices.yaml" or { };
  hassApply = nixosConfig.config.systemd.services.hass-apply-devices;

  execStart = hassApply.serviceConfig.ExecStart or "";
  execStartPre =
    let
      raw = hassApply.serviceConfig.ExecStartPre or [ ];
    in
    if builtins.isList raw then concatStringsSep "\n" raw else raw;

  assertions = [
    {
      test = !hasInfix "${haConfigDir}/devices.yaml" execStart;
      msg = "hass-apply-devices ExecStart must not depend on ${haConfigDir}/devices.yaml existing ahead of time";
    }
    {
      test = hasInfix "systemd-tmpfiles --create --remove --prefix ${haConfigDir}/devices.yaml" execStartPre;
      msg = "hass-apply-devices ExecStartPre must refresh ${haConfigDir}/devices.yaml via systemd-tmpfiles";
    }
    {
      test = devicesTmpfile ? "L+";
      msg = "10-hass-nix-yaml must manage ${haConfigDir}/devices.yaml with L+ so broken symlinks are replaced";
    }
    {
      test = !elem "${haConfigDir}/schemas/adaptive-lighting.json" (attrNames hassTmpfiles);
      msg = "10-hass-nix-yaml must not manage ${haConfigDir}/schemas/adaptive-lighting.json via tmpfiles";
    }
  ];

  failures = filter (a: !a.test) assertions;
  resultText =
    if failures == [ ] then
      "All ${toString (length assertions)} hass-apply-devices assertions passed."
    else
      concatStringsSep "\n" (
        [
          "${toString (length failures)}/${toString (length assertions)} hass-apply-devices assertions failed:"
        ]
        ++ map (a: "  FAIL: ${a.msg}") failures
      );
in
pkgs.runCommand "ha-apply-devices-assertions"
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
