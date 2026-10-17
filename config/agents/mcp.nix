{ lib, pkgs }:
let
  github = pkgs.writeShellScript "github-mcp" ''
    set -eu
    GITHUB_PERSONAL_ACCESS_TOKEN="$(${pkgs.gh}/bin/gh auth token)"
    export GITHUB_PERSONAL_ACCESS_TOKEN
    exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio
  '';
in
{
  github = {
    transport = lib.mkDefault "stdio";
    command = lib.mkDefault (toString github);
  };
  linear.url = lib.mkDefault "https://mcp.linear.app/mcp";
  seqera.url = lib.mkDefault "https://mcp.seqera.io/mcp";
  superlogical.url = lib.mkDefault "https://www.superlogical.com/rex/community-mcp";
  fff = {
    transport = lib.mkDefault "stdio";
    command = lib.mkDefault "${pkgs.my.fff-mcp}/bin/fff-mcp";
  };
  openaiDeveloperDocs.url = lib.mkDefault "https://developers.openai.com/mcp";
  homeassistant = {
    url = lib.mkDefault "https://homeassistant.cinnamon-rooster.ts.net/api/mcp";
    bearerTokenEnv = lib.mkDefault "HASS_TOKEN";
  };
}
