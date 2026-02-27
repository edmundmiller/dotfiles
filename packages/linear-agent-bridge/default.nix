# Linear Agent Bridge — openclaw gateway extension
#
# Receives Linear webhooks (@mentions, delegations) and dispatches them
# as autonomous agent runs via the openclaw gateway.
#
# OAuth token lifecycle:
#   - Tokens auto-rotate every 12h via linear-token-refresh.timer on the NUC
#   - Linear rotates refresh tokens on each use; the refresh script persists
#     the new refresh token to STATE_DIRECTORY/refresh-token
#   - If the refresh chain breaks: `linear-oauth-refresh` (bin/) re-bootstraps
#
# See hosts/nuc/AGENTS.md "Linear Agent Bridge" section for full docs.
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "linear-agent-bridge";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "edmundmiller";
    repo = "linear-agent-bridge";
    rev = "cb09637071dadf7a8bf5314310e1457ec4dd44d4";
    hash = "sha256-3XDUnMGyasBa5xRuVmcwfyUrlJ7adzl8wRjyDDjhDzY=";
  };

  npmDepsHash = "sha256-UPm3S6F9KKok1rpQbz0mYsC07YeHtFTBnAUip2k6Moc=";

  buildPhase = "npm run build";

  installPhase = ''
    mkdir -p $out/lib/linear-agent-bridge
    cp -r dist openclaw.plugin.json package.json $out/lib/linear-agent-bridge/
  '';

  meta = with lib; {
    description = "OpenClaw plugin: Linear → multi-agent workspace";
    homepage = "https://github.com/edmundmiller/linear-agent-bridge";
    license = licenses.mit;
  };
}
