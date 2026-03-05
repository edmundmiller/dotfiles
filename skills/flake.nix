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

    openai-skills = {
      url = "github:openai/skills";
      flake = false;
    };

    agent-tail-repo = {
      url = "github:gillkyle/agent-tail";
      flake = false;
    };

    pi-messenger-repo = {
      url = "github:nicobailon/pi-messenger";
      flake = false;
    };

    mitsuhiko-agent-stuff = {
      url = "github:mitsuhiko/agent-stuff";
      flake = false;
    };

    evals-skills = {
      url = "github:hamelsmu/evals-skills";
      flake = false;
    };

    shaping-skills = {
      url = "github:rjs/shaping-skills";
      flake = false;
    };
  };

  outputs = inputs: {
    homeManagerModules.default =
      { ... }:
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

            jut = {
              path = ../packages/jut/skill;
              filter.maxDepth = 1;
            };

            # Remote skill repos (hash-pinned via this flake's lock)
            pi-extensions = {
              path = inputs.pi-extension-skills.outPath;
              subdir = ".";
              filter.maxDepth = 2;
            };

            openai = {
              path = inputs.openai-skills.outPath;
              subdir = "skills/.curated";
              filter.maxDepth = 2;
            };

            agent-tail = {
              path = inputs.agent-tail-repo.outPath;
              subdir = "skills";
              filter.maxDepth = 2;
            };

            pi-messenger = {
              path = inputs.pi-messenger-repo.outPath;
              subdir = "skills";
              filter.maxDepth = 2;
            };

            mitsuhiko = {
              path = inputs.mitsuhiko-agent-stuff.outPath;
              subdir = "skills/tmux";
              filter.maxDepth = 1;
            };

            evals = {
              path = inputs.evals-skills.outPath;
              subdir = "skills";
              filter.maxDepth = 2;
            };

            shaping = {
              path = inputs.shaping-skills.outPath;
              subdir = ".";
              filter.maxDepth = 1;
            };
          };

          # Enable all local skills, but avoid path-prefix conflicts in remote catalogs.
          skills.enableAll = [
            "local"
            "jut"
          ];
          skills.explicit = {
            extending-pi.from = "pi-extensions";
            extending-pi.path = "extending-pi";

            gh-fix-ci.from = "openai";
            gh-fix-ci.path = "gh-fix-ci";

            agent-tail.from = "agent-tail";
            agent-tail.path = "agent-tail";

            tmux.from = "mitsuhiko";
            tmux.path = ".";

            build-review-interface.from = "evals";
            build-review-interface.path = "build-review-interface";

            error-analysis.from = "evals";
            error-analysis.path = "error-analysis";

            eval-audit.from = "evals";
            eval-audit.path = "eval-audit";

            evaluate-rag.from = "evals";
            evaluate-rag.path = "evaluate-rag";

            generate-synthetic-data.from = "evals";
            generate-synthetic-data.path = "generate-synthetic-data";

            validate-evaluator.from = "evals";
            validate-evaluator.path = "validate-evaluator";

            write-judge-prompt.from = "evals";
            write-judge-prompt.path = "write-judge-prompt";

            # shaping-skills repo uses lowercase skill.md — incompatible with agent-skills-nix
            # shaping.from = "shaping";
            # shaping.path = "shaping";
            # breadboarding.from = "shaping";
            # breadboarding.path = "breadboarding";
            # breadboard-reflection.from = "shaping";
            # breadboard-reflection.path = "breadboard-reflection";
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

            codex = {
              enable = true;
              dest = ".codex/skills";
              structure = "symlink-tree";
            };
          };
        };
      };
  };
}
