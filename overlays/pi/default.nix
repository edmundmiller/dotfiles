final: prev:
let
  # Pi 1.0 needs the codemode worker and new native platform assets. Reuse the
  # upstream packaging without updating every agent in the shared flake input.
  source = builtins.getFlake "github:numtide/llm-agents.nix/4bf9e89967f7c00cf5c5fc85a2741169267d2e1d";
in
{
  llm-agents = (prev.llm-agents or { }) // {
    pi = source.packages.${final.stdenv.hostPlatform.system}.pi;
  };
}
