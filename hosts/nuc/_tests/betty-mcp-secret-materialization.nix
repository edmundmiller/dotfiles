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
  materializesEveryMcpBearerToken = builtins.all (
    envVar: pkgs.lib.hasInfix envVar secretMaterialization
  ) expectedEnvVars;
  pantrySecretConfigured = builtins.hasAttr "hermes-betty-pantry-persona-api-key" nixosConfig.config.age.secrets;
  pantrySecretPath =
    if pantrySecretConfigured then
      nixosConfig.config.age.secrets."hermes-betty-pantry-persona-api-key".path
    else
      "";
  pantryReference = bettyAgentSpec.hermes.mcpBearerTokenReferences."pantry-persona";
  pantryUsesAgenix =
    pantrySecretConfigured
    && pkgs.lib.hasInfix pantrySecretPath secretMaterialization
    && !pkgs.lib.hasInfix pantryReference secretMaterialization;
  expectedFailure = false;
  pantryAgenixExpectedFailure = true;
  assertion =
    if expectedFailure then !materializesEveryMcpBearerToken else materializesEveryMcpBearerToken;
  pantryAgenixAssertion = if pantryAgenixExpectedFailure then !pantryUsesAgenix else pantryUsesAgenix;
in
pkgs.runCommand "nuc-betty-mcp-secret-materialization" { } ''
  if [ ${if assertion then "0" else "1"} -ne 0 ]; then
    echo "Betty must materialize every agent-declared MCP bearer token." >&2
    exit 1
  fi
  if [ ${if pantryAgenixAssertion then "0" else "1"} -ne 0 ]; then
    echo "Agenix must own Betty's Pantry Persona bearer token without direct activation-time reads." >&2
    exit 1
  fi

  mkdir -p "$out"
  echo "Betty MCP bearer token materialization assertion passed" > "$out/result"
''
