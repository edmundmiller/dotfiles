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

    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    hunk-repo = {
      url = "github:modem-dev/hunk/v0.15.3";
      flake = false;
    };

    herdr-repo = {
      url = "github:ogulcancelik/herdr";
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

    marimo-pair-repo = {
      url = "github:marimo-team/marimo-pair";
      flake = false;
    };

    marimo-skills-repo = {
      url = "github:marimo-team/skills";
      flake = false;
    };

    prek-repo = {
      url = "github:j178/prek";
      flake = false;
    };

    stack-repo = {
      url = "github:kitlangton/stack/v0.1.5";
      flake = false;
    };

    gitbutler-repo = {
      url = "github:gitbutlerapp/gitbutler";
      flake = false;
    };

    bholmesdev-skills = {
      url = "github:bholmesdev/skills";
      flake = false;
    };

  };

  outputs = inputs: {
    homeManagerModules.default =
      {
        lib,
        osConfig ? null,
        ...
      }:
      let
        moduleEnabled = path: if osConfig == null then false else lib.attrByPath path false osConfig;

        acpxEnabled = moduleEnabled [
          "modules"
          "shell"
          "acpx"
          "enable"
        ];
        gitEnabled = moduleEnabled [
          "modules"
          "shell"
          "git"
          "enable"
        ];
        diffityEnabled = moduleEnabled [
          "modules"
          "shell"
          "git"
          "diffity"
          "enable"
        ];
        gitbutlerEnabled = moduleEnabled [
          "modules"
          "shell"
          "git"
          "gitbutler"
          "enable"
        ];
        piEnabled = moduleEnabled [
          "modules"
          "agents"
          "pi"
          "enable"
        ];
        herdrEnabled = moduleEnabled [
          "modules"
          "shell"
          "herdr"
          "enable"
        ];
        hunkEnabled = moduleEnabled [
          "modules"
          "shell"
          "git"
          "hunk"
          "enable"
        ];
        stackEnabled =
          gitEnabled
          && moduleEnabled [
            "modules"
            "shell"
            "git"
            "stack"
            "enable"
          ];
        tmuxEnabled = moduleEnabled [
          "modules"
          "shell"
          "tmux"
          "enable"
        ];
        # Keep host-specific local skills out of the always-on catalog source so
        # they can be toggled by the matching Nix module below. Use a filtered
        # source path instead of a derivation so other NixOS configs can refer
        # to programs.agent-skills.bundlePath during evaluation on a different
        # build platform.
        localCatalogSource = builtins.path {
          name = "dotfiles-skills-catalog";
          path = ./catalog;
          filter =
            path: _type:
            let
              root = toString ./catalog;
              rel = lib.removePrefix "${root}/" (toString path);
              top = builtins.head (lib.splitString "/" rel);
            in
            rel == toString path || top != "herdr-pi-workspace";
        };
      in
      {
        imports = [ inputs.agent-skills.homeManagerModules.default ];

        programs.agent-skills = {
          enable = true;

          sources = {
            # Checkout-owned global skills.
            catalog = {
              path = localCatalogSource;
              subdir = ".";
              filter.maxDepth = 1;
            };

            herdr-pi-workspace = {
              path = ./catalog;
              subdir = ".";
              filter = {
                maxDepth = 1;
                nameRegex = "^herdr-pi-workspace$";
              };
            };

            gitbutler-but = {
              path = inputs.gitbutler-repo.outPath;
              subdir = "crates/but/skill";
              filter.maxDepth = 2;
            };

            gitbutler-agentlog = {
              path = inputs.gitbutler-repo.outPath;
              subdir = "crates/but-agentlog/skill";
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

            mattpocock-engineering = {
              path = inputs.mattpocock-skills.outPath;
              subdir = "skills/engineering";
              filter = {
                maxDepth = 1;
                nameRegex = "^(improve-codebase-architecture|to-prd|to-issues|grill-with-docs)$";
              };
            };

            mattpocock-productivity = {
              path = inputs.mattpocock-skills.outPath;
              subdir = "skills/productivity";
              filter = {
                maxDepth = 1;
                nameRegex = "^grill-me$";
              };
            };

            hunk = {
              path = inputs.hunk-repo.outPath;
              subdir = "skills";
              filter.maxDepth = 2;
            };

            herdr = {
              # Herdr exposes a single root-level SKILL.md upstream. Keep a
              # checkout-owned wrapper directory so cross-system evaluation does
              # not need a host-platform wrapper derivation.
              path = ./conditional/herdr;
              subdir = ".";
              filter.maxDepth = 1;
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

            marimo-pair = {
              path = inputs.marimo-pair-repo.outPath;
              subdir = "skills";
              filter.maxDepth = 2;
            };

            marimo-skills = {
              path = inputs.marimo-skills-repo.outPath;
              subdir = "skills";
              filter.maxDepth = 1;
            };

            prek = {
              path = inputs.prek-repo.outPath;
              subdir = "skills";
              filter.maxDepth = 1;
            };

            bholmesdev = {
              path = inputs.bholmesdev-skills.outPath;
              subdir = "skills";
              idPrefix = "bholmesdev";
              filter.maxDepth = 1;
            };

          }
          // lib.optionalAttrs stackEnabled {
            stack = {
              path = inputs.stack-repo.outPath;
              subdir = "skills/stack";
              filter.maxDepth = 1;
            };
          };

          # Enable all checkout-owned skills, but avoid path-prefix conflicts in remote catalogs.
          skills.enableAll = [ "catalog" ];
          skills.explicit =
            lib.optionalAttrs piEnabled {
              extending-pi.from = "pi-extensions";
              extending-pi.path = "extending-pi";
            }
            // {
              gh-fix-ci.from = "openai";
              gh-fix-ci.path = "gh-fix-ci";

              agent-tail.from = "agent-tail";
              agent-tail.path = "agent-tail";

              # Mitsuhiko's tmux skill is only useful on hosts where tmux itself is enabled.
            }
            // lib.optionalAttrs tmuxEnabled {
              tmux.from = "mitsuhiko";
              tmux.path = ".";
            }
            // lib.optionalAttrs hunkEnabled {
              hunk-review.from = "hunk";
              hunk-review.path = "hunk-review";
            }
            // lib.optionalAttrs gitbutlerEnabled {
              but.from = "gitbutler-but";
              but.path = ".";

              but-agentlog.from = "gitbutler-agentlog";
              but-agentlog.path = ".";
            }
            // lib.optionalAttrs stackEnabled {
              stack.from = "stack";
              stack.path = ".";
            }
            // lib.optionalAttrs herdrEnabled {
              # Herdr ships a root-level SKILL.md for agents controlling a live herdr
              # session via its local socket. Only enable it on hosts where the herdr
              # module is actually turned on.
              herdr.from = "herdr";
              herdr.path = "herdr";

              herdr-pi-workspace.from = "herdr-pi-workspace";
              herdr-pi-workspace.path = "herdr-pi-workspace";
            }
            // lib.optionalAttrs diffityEnabled {
              diffity-diff.from = "diffity";
              diffity-diff.path = "diffity-diff";

              diffity-review.from = "diffity";
              diffity-review.path = "diffity-review";

              diffity-resolve.from = "diffity";
              diffity-resolve.path = "diffity-resolve";
            }
            // {
              markit.from = "markit";
              markit.path = ".";

              prek.from = "prek";
              prek.path = "prek";

              done.from = "bholmesdev";
              done.path = "done";

              grill-me = {
                from = "mattpocock-productivity";
                path = "grill-me";
                transform =
                  { original, ... }:
                  ''
                    ${original}

                    ## Pi integration

                    When running in Pi and the `ask_user` tool is available, use it for every
                    user-facing grilling question instead of asking in plain chat. Keep the
                    interview adaptive: ask one question per `ask_user` call, inspect the answer,
                    then choose the next question.

                    For each `ask_user` call:
                    - Use `type: "single"` for normal decision questions, `type: "multi"` when
                      several answers can be true, and `type: "preview"` for comparing longer
                      designs/options.
                    - Include your recommended answer as an option or clearly mark it in an
                      option description.
                    - Include an `other` / `needs_custom_answer` option when the provided choices
                      may not fit, so the user can add notes.
                    - Keep prompts short and direct; put tradeoffs in option descriptions or
                      preview text.

                    If `ask_user` is not available, fall back to asking one question at a time in
                    plain chat.
                  '';
              };

              to-prd.from = "mattpocock-engineering";
              to-prd.path = "to-prd";

              to-issues.from = "mattpocock-engineering";
              to-issues.path = "to-issues";

              improve-codebase-architecture.from = "mattpocock-engineering";
              improve-codebase-architecture.path = "improve-codebase-architecture";

              grill-with-docs.from = "mattpocock-engineering";
              grill-with-docs.path = "grill-with-docs";
            }
            // lib.optionalAttrs acpxEnabled {
              acpx.from = "acpx";
              acpx.path = "acpx";
            }
            // {
              marimo-pair.from = "marimo-pair";
              marimo-pair.path = "marimo-pair";

              # Curated marimo subset: keep the broad, reusable notebook authoring
              # and migration skills; omit niche publishing helpers and overlapping
              # no-user-input workflows.
              anywidget-generator.from = "marimo-skills";
              anywidget-generator.path = "anywidget";

              implement-paper.from = "marimo-skills";
              implement-paper.path = "implement-paper";

              jupyter-to-marimo.from = "marimo-skills";
              jupyter-to-marimo.path = "jupyter-to-marimo";

              marimo-notebook.from = "marimo-skills";
              marimo-notebook.path = "marimo-notebook";

              streamlit-to-marimo.from = "marimo-skills";
              streamlit-to-marimo.path = "streamlit-to-marimo";

              wasm-compatibility.from = "marimo-skills";
              wasm-compatibility.path = "wasm-compatibility";

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
