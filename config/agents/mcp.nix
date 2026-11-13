# Prefer hosted HTTP servers: stdio servers start one process per agent session.
{ lib, pkgs }:
{
  # GITHUB_PAT comes from `gh auth token` in the login environment.
  github = {
    url = lib.mkDefault "https://api.githubcopilot.com/mcp/";
    bearerTokenEnv = lib.mkDefault "GITHUB_PAT";
  };
  browse = {
    transport = lib.mkDefault "stdio";
    command = lib.mkDefault "${pkgs.my.opencode-browse}/bin/browse";
    args = lib.mkDefault [ "mcp" ];
  };
  linear.url = lib.mkDefault "https://mcp.linear.app/mcp";
  notion = {
    url = lib.mkDefault "https://mcp.notion.com/mcp";
    excludeAgents = lib.mkDefault [ "amp" ];
  };
  seqera.url = lib.mkDefault "https://mcp.seqera.io/mcp";
  superlogical.url = lib.mkDefault "https://www.superlogical.com/rex/community-mcp";
  openaiDeveloperDocs.url = lib.mkDefault "https://developers.openai.com/mcp";
  homeassistant = {
    url = lib.mkDefault "https://homeassistant.cinnamon-rooster.ts.net/api/mcp";
    bearerTokenEnv = lib.mkDefault "HASS_TOKEN";
  };
}
