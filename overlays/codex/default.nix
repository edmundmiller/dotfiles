final: prev:
let
  # Upgrade Codex independently of the other agents in the shared input.
  source = builtins.getFlake "github:numtide/llm-agents.nix/2add2fd83bf01a23357d401ba24155e35d9d93d2";
in
{
  llm-agents = (prev.llm-agents or { }) // {
    codex = source.packages.${final.stdenv.hostPlatform.system}.codex;
  };
}
