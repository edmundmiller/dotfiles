{
  description = "Dotfiles agent skills catalog (child flake)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    agent-skills.url = "github:Kyure-A/agent-skills-nix";

    # Skill sources (flake = false for hash-pinned content)
    pi-extension-skills = {
      url = "github:tmustier/pi-extensions";
      flake = false;
    };

    gitbutler-repo = {
      url = "github:gitbutlerapp/gitbutler";
      flake = false;
    };

    openai-skills = {
      url = "github:openai/skills";
      flake = false;
    };
  };

  outputs = inputs: {
    homeManagerModules.default =
      { config, ... }:
      {
        imports = [ inputs.agent-skills.homeManagerModules.default ];

        programs.agent-skills = {
          enable = true;

          sources = {
            # Local skills from dotfiles repo (copied into store by HM)
            local = {
              # Local skills from this dotfiles repo (in flake source/store)
              path = ../config/agents/skills;
              filter.maxDepth = 1;
            };

            # Remote skill repos (hash-pinned via this flake's lock)
            pi-extensions = {
              path = inputs.pi-extension-skills.outPath;
              subdir = ".";
              filter.maxDepth = 2;
            };

            gitbutler = {
              path = inputs.gitbutler-repo.outPath;
              subdir = "crates/but";
              filter.maxDepth = 2;
            };

            openai = {
              path = inputs.openai-skills.outPath;
              subdir = "skills/.curated";
              filter.maxDepth = 2;
            };
          };

          # Enable all local skills, but avoid path-prefix conflicts in remote catalogs.
          skills.enableAll = [ "local" ];
          skills.explicit = {
            extending-pi.from = "pi-extensions";
            extending-pi.path = "extending-pi";

            # GitButler CLI skill (source: gitbutlerapp/gitbutler/crates/but/skill)
            but.from = "gitbutler";
            but.path = "skill";

            gh-fix-ci.from = "openai";
            gh-fix-ci.path = "gh-fix-ci";
          };

          targets = {
            # opt-in targets
            claude = {
              enable = true;
              structure = "symlink-tree";
            };

            pi = {
              enable = true;
              dest = ".pi/agent/skills";
              structure = "symlink-tree";
            };

            opencode = {
              enable = true;
              dest = ".config/opencode/skill";
              structure = "symlink-tree";
            };
          };
        };
      };
  };
}
