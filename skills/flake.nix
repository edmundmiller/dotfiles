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

    shaping-skills = {
      url = "github:rjs/shaping-skills";
      flake = false;
    };

    hunk-repo = {
      url = "github:modem-dev/hunk/v0.9.2";
      flake = false;
    };

    diffity-repo = {
      url = "github:kamranahmedse/diffity";
      flake = false;
    };

    qmd-repo = {
      url = "github:tobi/qmd";
      flake = false;
    };

    markit-repo = {
      url = "github:Michaelliv/markit";
      flake = false;
    };

    acpx-repo = {
      url = "github:openclaw/acpx";
      flake = false;
    };

    mattpocock-skills = {
      url = "git+https://github.com/mattpocock/skills";
      flake = false;
    };

    # Child flake cannot reference ../ paths once materialized in /nix/store.
    # Pull repo-local skill dirs from dotfiles source instead.
    dotfiles-repo = {
      url = "github:edmundmiller/dotfiles";
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
            # Local skills from dotfiles repo
            local = {
              path = inputs.dotfiles-repo.outPath;
              subdir = "config/agents/skills";
              filter.maxDepth = 1;
            };

            jut = {
              path = inputs.dotfiles-repo.outPath;
              subdir = "packages/jut/skill";
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

            shaping = {
              path = inputs.shaping-skills.outPath;
              subdir = ".";
              filter.maxDepth = 1;
            };

            hunk = {
              path = inputs.hunk-repo.outPath;
              subdir = "skills";
              filter.maxDepth = 2;
            };

            diffity = {
              path = inputs.diffity-repo.outPath;
              subdir = "skills";
              filter.maxDepth = 2;
            };

            markit = {
              path = inputs.markit-repo.outPath;
              subdir = ".";
              filter.maxDepth = 1;
            };

            acpx = {
              path = inputs.acpx-repo.outPath;
              subdir = "skills";
              filter.maxDepth = 2;
            };

            mattpocock = {
              path = inputs.mattpocock-skills.outPath;
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

            hunk-review.from = "hunk";
            hunk-review.path = "hunk-review";

            diffity-diff.from = "diffity";
            diffity-diff.path = "diffity-diff";

            diffity-review.from = "diffity";
            diffity-review.path = "diffity-review";

            diffity-resolve.from = "diffity";
            diffity-resolve.path = "diffity-resolve";

            markit.from = "markit";
            markit.path = ".";

            acpx.from = "acpx";
            acpx.path = "acpx";

            grill-me.from = "mattpocock";
            grill-me.path = "grill-me";

            write-a-prd.from = "mattpocock";
            write-a-prd.path = "to-prd";

            prd-to-issues.from = "mattpocock";
            prd-to-issues.path = "to-issues";

            matt-tdd.from = "mattpocock";
            matt-tdd.path = "tdd";

            improve-codebase-architecture.from = "mattpocock";
            improve-codebase-architecture.path = "improve-codebase-architecture";

            # shaping-skills repo uses lowercase skill.md — incompatible with agent-skills-nix
            # shaping.from = "shaping";
            # shaping.path = "shaping";
            # breadboarding.from = "shaping";
            # breadboarding.path = "breadboarding";
            # breadboard-reflection.from = "shaping";
            # breadboard-reflection.path = "breadboard-reflection";
          };

          targets = {
            # Canonical shared global skills location. Codex, Pi, OpenCode,
            # and Hermes should all read from ~/.agents/skills directly.
            agents = {
              enable = true;
              dest = ".agents/skills";
              # Hermes skill discovery uses pathlib.rglob("SKILL.md"), which
              # does not recurse into symlinked directories. Use copy-tree so
              # ~/.agents/skills contains real directories Hermes can discover.
              structure = "copy-tree";
            };
          };
        };
      };
  };
}
