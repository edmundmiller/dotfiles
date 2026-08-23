{
  nixosConfig,
  pkgs,
  bettyAgentSpec,
}:
let
  secretMaterialization =
    nixosConfig.config.system.activationScripts.hermesBettySecretsMaterialize.text;
  expectedEnvVars = pkgs.lib.mapAttrsToList (
    serverName: _reference:
    "HERMES_MCP_BEARER_TOKEN_${pkgs.lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] serverName)}"
  ) bettyAgentSpec.hermes.mcpBearerTokenReferences;
  expectedReferences = builtins.attrValues bettyAgentSpec.hermes.mcpBearerTokenReferences;
  opnixReferences = pkgs.lib.mapAttrsToList (
    _name: secret: secret.reference
  ) nixosConfig.config.services.onepassword-secrets.secrets;
  materializesEveryMcpBearerToken = builtins.all (
    envVar: pkgs.lib.hasInfix envVar secretMaterialization
  ) expectedEnvVars;
  opnixOwnsEveryMcpBearerToken =
    builtins.all (reference: builtins.elem reference opnixReferences) expectedReferences
    && !pkgs.lib.hasInfix "/bin/op read " secretMaterialization;
  expectedFailure = false;
  opnixExpectedFailure = true;
  assertion =
    if expectedFailure then !materializesEveryMcpBearerToken else materializesEveryMcpBearerToken;
  opnixAssertion =
    if opnixExpectedFailure then !opnixOwnsEveryMcpBearerToken else opnixOwnsEveryMcpBearerToken;
in
pkgs.runCommand "nuc-betty-mcp-secret-materialization" { } ''
  if [ ${if assertion then "0" else "1"} -ne 0 ]; then
    echo "Betty must materialize every agent-declared MCP bearer token." >&2
    exit 1
  fi
  if [ ${if opnixAssertion then "0" else "1"} -ne 0 ]; then
    echo "OpNix must own Betty's MCP bearer tokens without direct activation-time reads." >&2
    exit 1
  fi

  mkdir -p "$out"
  echo "Betty MCP bearer token materialization assertion passed" > "$out/result"
''
