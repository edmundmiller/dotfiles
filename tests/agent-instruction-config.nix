{
  lib,
  inputs,
  coreutils,
  root ? ../.,
}:
let
  moduleLib = lib // {
    my = (import ../lib/options.nix { inherit lib; }) // (import ../lib/jsonc.nix { inherit lib; });
    hm.dag.entryAfter = after: data: { inherit after data; };
  };
  config = {
    dotfiles.configDir = root + /config;
    user = {
      name = "test";
      home = "/tmp/agent-instruction-test";
    };
    modules = {
      agents =
        lib.genAttrs [ "codex" "claude" "pi" "opencode" ] (_: {
          enable = true;
        })
        // {
          pi = {
            enable = true;
            classifierModel = null;
            extraPackages = [ ];
            enabledModels = [ ];
            defaultProvider = null;
            defaultModel = null;
            computerUse.enable = false;
            gitTools.enable = false;
            statusUi.enable = false;
            contextMemory.enable = false;
            cursorSdk.enable = false;
            honcho.enable = false;
          };
          claude = {
            enable = true;
            pstack.enable = true;
          };
        };
      desktop.term.ghostty.enable = false;
      shell.herdr = {
        enable = false;
      };
    };
  };
  # Force instructions and Pi approval deployment, not package builds or secrets.
  # These modules return mkIf enable bodies.
  loadWith =
    moduleConfig: name:
    let
      result =
        (import (root + "/modules/agents/${name}/default.nix") {
          inherit inputs;
          config = moduleConfig;
          lib = moduleLib;
          pkgs.coreutils = coreutils;
          pkgs.python3 = "/fixture/python3";
          pkgs.llm-agents.claude-code = "/fixture/claude-code";
          pkgs.my.pi-github-tools = "/fixture/pi-github-tools";
          pkgs.my.pistack = "/fixture/pistack";
          isDarwin = false;
        }).config;
    in
    assert result.condition;
    result.content;
  load = loadWith config;
  t3ClaudeActivation =
    packageEnabled:
    let
      selectedConfig = lib.recursiveUpdate config {
        modules.agents.claude.package.enable = packageEnabled;
      };
      selectedHome = (loadWith selectedConfig "claude").home-manager.users.test {
        lib = moduleLib;
      };
    in
    selectedHome.home.activation.t3-claude-settings.content.data;
  home =
    name:
    (load name).home-manager.users.test {
      lib = moduleLib;
      config.home.homeDirectory = config.user.home;
    };
  skillsConfig =
    (
      ((import (root + "/skills/flake.nix")).outputs inputs.skills-catalog.inputs)
      .homeManagerModules.default
      {
        lib = moduleLib;
        config = { };
        pkgs = { };
      }
    ).config.programs;
  interviewSkills = inputs.skills-catalog.inputs.agent-skills.lib.agent-skills.selectSkills {
    catalog = { };
    sources = skillsConfig.agent-skills.sources;
    skills = lib.filterAttrs (
      _: skill: skill.from == "mattpocock"
    ) skillsConfig.dotfiles-agent-skills.targetedExplicit;
  };
  originalAskMatt = builtins.readFile (interviewSkills.ask-matt.absPath + "/SKILL.md");
in
{
  t3Claude = {
    nativeActivation = t3ClaudeActivation false;
    nixActivation = t3ClaudeActivation true;
  };
  interviews = {
    selected = builtins.attrNames interviewSkills;
    original = originalAskMatt;
    rendered = interviewSkills.ask-matt.transform { original = originalAskMatt; };
  };
  instructions = {
    ".codex/AGENTS.md" = (load "codex").home.file.".codex/AGENTS.md".text;
    ".claude/CLAUDE.md" = (load "claude").home.file.".claude/CLAUDE.md".text;
    ".pi/agent/AGENTS.md" = (home "pi").home.file.".pi/agent/AGENTS.md".text;
    ".config/opencode/AGENTS.md" =
      builtins.readFile
        (home "opencode").xdg.configFile."opencode/AGENTS.md".source;
  };
  piApproval = {
    settings = builtins.fromJSON (home "pi").home.file.".pi/agent/settings.json".text;
    policy = (home "pi").home.file.".pi/agent/extensions/pi-permission-system/config.json";
    homeFiles = builtins.attrNames (home "pi").home.file;
  };
  piSkills = {
    pistack = toString (home "pi").home.file.".pi/agent/packages/pistack".source;
    agentFiles = lib.filter (lib.hasPrefix ".pi/agent/agents/") (
      builtins.attrNames (home "pi").home.file
    );
  };
}
