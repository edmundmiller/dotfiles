# Agent skills management via agent-skills-nix
# Skills are pinned by flake.lock hashes — no prompt injection risk.
# Update skills: `nix flake update pi-extension-skills gitbutler-repo agent-skills`
{
  config,
  lib,
  ...
}:

with lib;
with lib.my;
let
  cfg = config.modules.shell.agents.skills;
  configDir = "${config.dotfiles.configDir}";
in
{
  options.modules.shell.agents.skills = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} =
      { inputs, ... }:
      {
        programs.agent-skills = {
          enable = true;

          sources = {
            # Local skills from this repo
            local = {
              path = "${configDir}/agents/skills";
              filter.maxDepth = 1;
            };
            # Remote skill repos (hash-pinned via flake.lock)
            pi-extensions = {
              # NOTE: agent-skills-nix resolveSourceRoot treats `path = null` as set.
              # Workaround: pass store path directly instead of `input = ...`.
              path = inputs.pi-extension-skills.outPath;
              subdir = ".";
              filter.maxDepth = 2;
            };
            gitbutler = {
              path = inputs.gitbutler-repo.outPath;
              subdir = "crates/but";
              filter.maxDepth = 2;
            };
          };

          # Enable all local skills, but avoid path-prefix conflicts in remote catalogs
          # (e.g. both `extending-pi` and `extending-pi/skill-creator` exist).
          skills.enableAll = [ "local" ];
          skills.explicit = {
            extending-pi.from = "pi-extensions";
            extending-pi.path = "extending-pi";

            # Flatten nested skill ID to avoid `extending-pi/*` under a symlink.
            skill-creator.from = "pi-extensions";
            skill-creator.path = "extending-pi/skill-creator";

            # GitButler CLI skill (source: gitbutlerapp/gitbutler/crates/but/skill)
            but.from = "gitbutler";
            but.path = "skill";
          };

          targets = {
            claude.enable = true;
            claude.structure = "link";

            pi = {
              enable = true;
              dest = ".pi/agent/skills";
              structure = "link";
            };
            opencode = {
              enable = true;
              dest = ".config/opencode/skill";
              structure = "link";
            };
          };
        };
      };
  };
}
