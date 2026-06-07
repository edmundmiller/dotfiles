{ inputs }:
final: prev:
let
  codex = inputs.llm-agents-codex.packages.${final.stdenv.hostPlatform.system}.codex;
in
{
  inherit codex;

  llm-agents = (prev.llm-agents or { }) // {
    inherit codex;
  };
}
