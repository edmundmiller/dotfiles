{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.git;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.git = {
    enable = mkBoolOpt false;
    ai.enable = mkBoolOpt false;
    hunk = {
      enable = mkBoolOpt false;
      version = mkOpt types.str "0.9.2";
    };
  };

  config = mkIf cfg.enable {
    assertions = optional cfg.hunk.enable {
      assertion = config.modules.dev.node.enable;
      message = "modules.shell.git.hunk.enable requires modules.dev.node.enable (for bun global hunkdiff install).";
    };

    modules.dev.node.bunGlobalPackages = optional cfg.hunk.enable "hunkdiff@${cfg.hunk.version}";

    user.packages = with pkgs; [
      git-open
      difftastic
      my.sem # semantic git diff/impact/blame
      my.inspect # entity-level code review triage
      my.weave # entity-level semantic merge driver
      my.diffity # GitHub-style diff viewer/code review
      delta # for lazygit paging
      (mkIf config.modules.shell.gnupg.enable git-crypt)
      git-lfs
      pre-commit
      my.git-hunks
    ];

    # Use home-manager's xdg.configFile directly for proper activation
    home-manager.users.${config.user.name} = {
      xdg.configFile = {
        "git/config".source = "${configDir}/git/config";
        "git/config-seqera".source = "${configDir}/git/config-seqera";
        "git/config-nfcore".source = "${configDir}/git/config-nfcore";
        "git/ignore".source = "${configDir}/git/ignore";
        "git/allowed_signers".source = "${configDir}/git/allowed_signers";
        # GitHub CLI config (hosts.yml intentionally NOT managed — gh writes
        # token/scope metadata to it after auth; Nix store symlink would block that)
        "gh/config.yml".source = "${configDir}/gh/config.yml";
        # GitHub Dashboard config
        "gh-dash/config.yml".source = "${configDir}/gh-dash/config.yml";
        # Lazygit config
        "lazygit/config.yml" = {
          text = builtins.readFile "${configDir}/lazygit/config.yml";
          force = true;
        };
      }
      // optionalAttrs cfg.hunk.enable {
        "hunk/config.toml".source = "${configDir}/hunk/config.toml";
      };
    };

    modules.shell.zsh.rcFiles = [ "${configDir}/git/aliases.zsh" ];

  };
}
