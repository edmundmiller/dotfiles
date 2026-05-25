{
  config,
  lib,
  pkgs,
  isDarwin,
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
    hunk.enable = mkBoolOpt false;
    gitbutler.enable = mkBoolOpt false;
    gitnexus.enable = mkBoolOpt false;
    lazydiff.enable = mkBoolOpt false;
    diffity.enable = mkBoolOpt false;
    stack.enable = mkBoolOpt true;
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.ai.enable {
      modules.agents.pi.extraPackages = mkIf config.modules.agents.pi.enable [
        "~/.config/dotfiles/pi-packages/pi-git-ai"
      ];
    })

    {
      user.packages =
        with pkgs;
        [
          git-open
          difftastic
          delta # for lazygit paging
          (mkIf config.modules.shell.gnupg.enable git-crypt)
          git-lfs
          pre-commit
          my.git-hunks
          (mkIf cfg.ai.enable my.git-ai)
          (mkIf cfg.gitbutler.enable llm-agents.but)
          (mkIf cfg.gitbutler.enable llm-agents.gitbutler)
          (mkIf cfg.gitnexus.enable llm-agents.gitnexus)
          (mkIf cfg.hunk.enable my.hunk)
          (mkIf cfg.lazydiff.enable my.lazydiff)
          (mkIf cfg.stack.enable my.stack)
        ]
        ++ lib.optionals stdenv.hostPlatform.isDarwin (
          [
            my.sem # semantic git diff/impact/blame
            my.inspect # entity-level code review triage
            my.weave # entity-level semantic merge driver
          ]
          ++ lib.optional cfg.diffity.enable my.diffity # GitHub-style diff viewer/code review
        );

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

      environment.variables.GHUI_PR_FETCH_LIMIT = "100";
    }

    (optionalAttrs isDarwin {
      homebrew.brews = [ "kitlangton/tap/ghui" ];
    })
  ]);
}
