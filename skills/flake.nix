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
      url = "github:modem-dev/hunk/v0.16.0";
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

    emilkowalski-skills = {
      url = "github:emilkowalski/skills";
      flake = false;
    };

    shadcn-improve = {
      url = "github:shadcn/improve";
      flake = false;
    };

    zele-repo = {
      url = "github:remorses/zele";
      flake = false;
    };

  };

  outputs = inputs: {
    homeManagerModules.default =
      {
        config,
        lib,
        osConfig ? null,
        pkgs,
        ...
      }:
      let
        agentLib = inputs.agent-skills.lib.agent-skills;
        scopedCfg = config.programs.dotfiles-agent-skills;
        moduleEnabled = path: if osConfig == null then false else lib.attrByPath path false osConfig;
        allSkillTargets = [
          "agents"
          "codex"
          "pi"
          "claude"
          "opencode"
          "hermes"
        ];
        targetAliases = {
          dot-agents = "agents";
          dot-codex = "codex";
          dot-pi = "pi";
          dot-claude = "claude";
          dot-opencode = "opencode";
          dot-hermes = "hermes";
        };
        normalizeTarget = target: targetAliases.${target} or target;
        # Pi, Codex, OpenCode, and Hermes read ~/.agents/skills in addition to
        # their own target dirs, so default skills go only to ~/.agents/skills.
        # Claude is the exception and needs its own default copy.
        defaultSkillTargets = [
          "agents"
          "claude"
        ];
        targetsForSkill = skill: map normalizeTarget (skill.meta.targets or defaultSkillTargets);
        targetDefs = {
          agents = {
            enable = true;
            dest = "$HOME/.agents/skills";
            structure = "copy-tree";
          };
          codex = {
            enable = true;
            dest = "$HOME/.codex/skills";
            structure = "copy-tree";
          };
          pi = {
            enable = true;
            dest = "$HOME/.pi/agent/skills";
            structure = "copy-tree";
          };
          claude = {
            enable = true;
            dest = "$HOME/.claude/skills";
            structure = "copy-tree";
          };
          opencode = {
            enable = true;
            dest = "$HOME/.config/opencode/skills";
            structure = "copy-tree";
          };
          hermes = {
            enable = true;
            dest = "$HOME/.hermes/skills";
            structure = "copy-tree";
          };
        };

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
        codexEnabled = moduleEnabled [
          "modules"
          "agents"
          "codex"
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
        claudeEnabled = moduleEnabled [
          "modules"
          "agents"
          "claude"
          "enable"
        ];
        opencodeEnabled = moduleEnabled [
          "modules"
          "agents"
          "opencode"
          "enable"
        ];
        hermesEnabled =
          moduleEnabled [
            "modules"
            "agents"
            "hermes"
            "enable"
          ]
          || moduleEnabled [
            "services"
            "hermes-agent"
            "enable"
          ];
        targetEnabled = {
          agents = codexEnabled || piEnabled || opencodeEnabled || hermesEnabled;
          codex = codexEnabled;
          pi = piEnabled;
          claude = claudeEnabled;
          opencode = opencodeEnabled;
          hermes = hermesEnabled;
        };
        activeSkillTargets = lib.filter (target: targetEnabled.${target}) allSkillTargets;
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

        options.programs.dotfiles-agent-skills = {
          targetedExplicit = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = ''
              Explicit skills with `meta.targets` used for target-specific
              bundles. Missing `meta.targets` means all dotfiles agent targets.
            '';
          };

          bundles = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "Generated per-agent skill bundle store paths.";
          };
        };

        config =
          let
            catalog = agentLib.discoverCatalog config.programs.agent-skills.sources;
            allowlist = agentLib.allowlistFor {
              inherit catalog;
              sources = config.programs.agent-skills.sources;
              enableAll = config.programs.agent-skills.skills.enableAll;
              enable = config.programs.agent-skills.skills.enable;
            };
            baseSelection = agentLib.selectSkills {
              inherit catalog allowlist;
              skills = config.programs.agent-skills.skills.explicit;
              sources = config.programs.agent-skills.sources;
            };
            targetedSelection = agentLib.selectSkills {
              inherit catalog;
              allowlist = [ ];
              skills = scopedCfg.targetedExplicit;
              sources = config.programs.agent-skills.sources;
            };
            selection = baseSelection // targetedSelection;
            selectionFor =
              target: lib.filterAttrs (_: skill: builtins.elem target (targetsForSkill skill)) selection;
            bundles = lib.genAttrs allSkillTargets (
              target:
              agentLib.mkBundle {
                inherit pkgs;
                selection = selectionFor target;
                name = "dotfiles-agent-skills-${target}";
              }
            );
            syncScripts = lib.genAttrs allSkillTargets (
              target:
              agentLib.mkSyncScript {
                inherit pkgs;
                bundle = bundles.${target};
                targets = {
                  ${target} = targetDefs.${target};
                };
                excludePatterns = config.programs.agent-skills.excludePatterns;
              }
            );
          in
          {
            programs.dotfiles-agent-skills.bundles = bundles;

            home.activation.dotfiles-agent-skills = lib.hm.dag.entryAfter [ "agent-skills" ] (
              lib.concatMapStringsSep "\n" (target: ''
                dest="${targetDefs.${target}.dest}"
                  if [ -L "$dest" ]; then
                    rm -f "$dest"
                  elif [ -e "$dest" ]; then
                    chmod -R u+w "$dest" 2>/dev/null || true
                  fi
              '') activeSkillTargets
              + "\n"
              + lib.concatStringsSep "\n" (map (target: syncScripts.${target}) activeSkillTargets)
            );

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
                    nameRegex = "^(ask-matt|codebase-design|diagnosing-bugs|domain-modeling|grill-with-docs|implement|improve-codebase-architecture|prototype|resolving-merge-conflicts|setup-matt-pocock-skills|to-issues|to-prd|triage)$";
                  };
                };

                mattpocock-productivity = {
                  path = inputs.mattpocock-skills.outPath;
                  subdir = "skills/productivity";
                  filter = {
                    maxDepth = 1;
                    nameRegex = "^(grill-me|grilling|handoff|teach|writing-great-skills)$";
                  };
                };

                mattpocock-in-progress = {
                  path = inputs.mattpocock-skills.outPath;
                  subdir = "skills/in-progress";
                  filter = {
                    maxDepth = 1;
                    nameRegex = "^loop-me$";
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

                emilkowalski = {
                  path = inputs.emilkowalski-skills.outPath;
                  subdir = "skills";
                  filter.maxDepth = 2;
                };

                shadcn-improve = {
                  path = inputs.shadcn-improve.outPath;
                  subdir = "skills";
                  filter.maxDepth = 2;
                };

                zele = {
                  path = inputs.zele-repo.outPath;
                  subdir = "skills";
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

                  zele.from = "zele";
                  zele.path = "zele";

                  animation-vocabulary.from = "emilkowalski";
                  animation-vocabulary.path = "animation-vocabulary";

                  apple-design.from = "emilkowalski";
                  apple-design.path = "apple-design";

                  emil-design-eng.from = "emilkowalski";
                  emil-design-eng.path = "emil-design-eng";

                  review-animations.from = "emilkowalski";
                  review-animations.path = "review-animations";

                  improve.from = "shadcn-improve";
                  improve.path = "improve";

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

                  codebase-design.from = "mattpocock-engineering";
                  codebase-design.path = "codebase-design";

                  domain-modeling.from = "mattpocock-engineering";
                  domain-modeling.path = "domain-modeling";

                  improve-codebase-architecture.from = "mattpocock-engineering";
                  improve-codebase-architecture.path = "improve-codebase-architecture";

                  grill-with-docs.from = "mattpocock-engineering";
                  grill-with-docs.path = "grill-with-docs";

                  ask-matt.from = "mattpocock-engineering";
                  ask-matt.path = "ask-matt";

                  diagnosing-bugs.from = "mattpocock-engineering";
                  diagnosing-bugs.path = "diagnosing-bugs";

                  implement.from = "mattpocock-engineering";
                  implement.path = "implement";

                  prototype.from = "mattpocock-engineering";
                  prototype.path = "prototype";

                  resolving-merge-conflicts.from = "mattpocock-engineering";
                  resolving-merge-conflicts.path = "resolving-merge-conflicts";

                  triage.from = "mattpocock-engineering";
                  triage.path = "triage";

                  grilling.from = "mattpocock-productivity";
                  grilling.path = "grilling";

                  handoff.from = "mattpocock-productivity";
                  handoff.path = "handoff";

                  teach.from = "mattpocock-productivity";
                  teach.path = "teach";

                  writing-great-skills.from = "mattpocock-productivity";
                  writing-great-skills.path = "writing-great-skills";

                  setup-matt-pocock-skills.from = "mattpocock-engineering";
                  setup-matt-pocock-skills.path = "setup-matt-pocock-skills";

                  loop-me.from = "mattpocock-in-progress";
                  loop-me.path = "loop-me";
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
                # Canonical dot-agents target. Other agents get their own
                # generated target dirs from dotfiles-agent-skills.
                agents = {
                  enable = true;
                  dest = ".agents/skills";
                  structure = "copy-tree";
                };
              };
            };

            programs.dotfiles-agent-skills.targetedExplicit = lib.optionalAttrs piEnabled {
              herdr-pi-workspace = {
                from = "herdr-pi-workspace";
                path = "herdr-pi-workspace";
                meta.targets = [ "pi" ];
              };
            };
          };
      };
  };
}
