# Pure Nix eval test: routine NixOS switches must not interrupt an enabled
# Hermes gateway that may be carrying an interactive conversation.
{
  nixosConfig,
  pkgs,
}:
let
  cfg = nixosConfig.config;
  gatewayNames = builtins.filter (name: builtins.match "hermes-gateway-.*" name != null) (
    builtins.attrNames cfg.systemd.services
  );
  enabledGatewayNames = builtins.filter (
    name: cfg.systemd.services.${name}.enable or false
  ) gatewayNames;
  violations = builtins.filter (
    name: (cfg.systemd.services.${name}.restartIfChanged or null) != false
  ) enabledGatewayNames;
  violationText = builtins.concatStringsSep "\n" (
    map (
      name: "- ${name}: restartIfChanged must be false for an enabled interactive gateway"
    ) violations
  );
in
pkgs.runCommand "nuc-hermes-gateway-restart-policy" { } ''
  if [ ${toString (builtins.length enabledGatewayNames)} -eq 0 ]; then
    echo "No enabled Hermes gateway services were found" >&2
    exit 1
  fi
  if [ ${toString (builtins.length violations)} -ne 0 ]; then
    cat >&2 <<'EOF'
  Enabled Hermes gateway restart policy assertions failed:
  ${violationText}
  EOF
    exit 1
  fi
  touch "$out"
''
