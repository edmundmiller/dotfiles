final: prev:
let
  # Pi 1.4.0 needs the codemode worker and new native platform assets. Reuse the
  # upstream packaging without updating every agent in the shared flake input.
  source = builtins.getFlake "github:numtide/llm-agents.nix/8a5736991e143964a1494333354822ceadd32b05";
in
{
  llm-agents = (prev.llm-agents or { }) // {
    pi = source.packages.${final.stdenv.hostPlatform.system}.pi;
  };
}
