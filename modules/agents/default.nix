{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.agents;
  # Starts the host's default coding agent, or `--agent NAME`, with an optional
  # first prompt. Each agent spells "start interactive with this message" its own way.
  codingAgent = pkgs.writeShellApplication {
    name = "coding-agent";
    text = ''
      agent=''${DEFAULT_CODING_AGENT:-${cfg.default}}
      if [[ ''${1:-} == --agent ]]; then
        agent=''${2:?--agent needs a command name}
        shift 2
      fi
      prompt=''${1:-}
      if [[ $agent == amp && -n $prompt ]]; then
        # Amp has no prompt argument; a piped message starts an interactive session.
        exec amp < <(printf '%s\n' "$prompt")
      fi
      exec "$agent" ''${prompt:+"$prompt"}
    '';
  };
in
{
  options.modules.agents.default = lib.mkOption {
    type = lib.types.strMatching "[A-Za-z0-9._-]+";
    default = "pi";
    example = "amp";
    description = ''
      Host-wide default coding agent command. Exported as `DEFAULT_CODING_AGENT`
      (a repo can override it with direnv or mise) and launched by `coding-agent`.
    '';
  };

  config = {
    env.DEFAULT_CODING_AGENT = cfg.default;
    user.packages = [
      codingAgent
      pkgs.my.bend
      pkgs.my.callstack-diff
      pkgs.my.fx
      pkgs.my.sgrep
    ];
  };
}
