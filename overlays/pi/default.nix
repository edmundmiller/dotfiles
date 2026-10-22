final: prev:
let
  # Pi 1.3.0 needs the codemode worker and new native platform assets. Reuse the
  # upstream packaging without updating every agent in the shared flake input.
  source = builtins.getFlake "github:numtide/llm-agents.nix/c250766160603f5ef582adecb4f453b009f63365";
in
{
  llm-agents = (prev.llm-agents or { }) // {
    pi = source.packages.${final.stdenv.hostPlatform.system}.pi;
  };
}
