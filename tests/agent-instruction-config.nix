{
  lib,
  coreutils,
  root ? ../.,
}:
let
  moduleLib = lib // {
    my = import ../lib/options.nix { inherit lib; };
    hm.dag.entryAfter = after: data: { inherit after data; };
  };
  config = {
    dotfiles.configDir = root + /config;
    user = {
      name = "test";
      home = "/tmp/agent-instruction-test";
    };
    modules = {
      agents = lib.genAttrs [ "omp" "codex" "claude" "pi" "opencode" ] (_: {
        enable = true;
      });
      desktop.term.ghostty.enable = false;
    };
  };
  # Only force instruction files and the compatibility activation, not packages
  # or unrelated runtime settings. These modules return mkIf enable bodies.
  load =
    name:
    let
      result =
        (import (root + "/modules/agents/${name}/default.nix") {
          inherit config;
          lib = moduleLib;
          pkgs.coreutils = coreutils;
          isDarwin = false;
        }).config;
    in
    assert result.condition;
    result.content;
  home =
    name:
    (load name).home-manager.users.test {
      lib = moduleLib;
      config.home.homeDirectory = config.user.home;
    };
  files = (load "omp").home.file;
in
{
  instructions = {
    ".omp/agent/AGENTS.md" = files.".omp/agent/AGENTS.md".text;
    ".codex/AGENTS.md" = (load "codex").home.file.".codex/AGENTS.md".text;
    ".claude/CLAUDE.md" = (load "claude").home.file.".claude/CLAUDE.md".text;
    ".pi/agent/AGENTS.md" = (home "pi").home.file.".pi/agent/AGENTS.md".text;
    ".config/opencode2/opencode/AGENTS.md" =
      builtins.readFile
        (home "opencode").xdg.configFile."opencode2/opencode/AGENTS.md".source;
  };
  ompRules = lib.filter (lib.hasPrefix ".omp/agent/rules/") (builtins.attrNames files);
  fixAgentsPrompt = builtins.readFile files.".omp/agent/commands/fix-agents-md.md".source;
  opencodeCompatibility = (home "opencode").home.activation.opencode-v1-cleanup.data;
}
