# modules/shell/bugwarrior.nix
# Bugwarrior configuration for syncing issues from GitHub, Linear, etc. to Taskwarrior
# Secrets are managed via opnix (1Password integration) on Darwin
{
  config,
  options,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.bugwarrior;
  inherit (config.dotfiles) configDir;
  # Secret paths for bugwarrior - use macOS-appropriate location
  secretsDir = "/usr/local/var/opnix/secrets";
in
{
  options.modules.shell.bugwarrior = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # Bugwarrior requires taskwarrior
    modules.shell.taskwarrior.enable = true;

    # Configure opnix secrets service for bugwarrior (Darwin only)
    # Secrets are fetched from 1Password and stored at /usr/local/var/opnix/secrets/
    services.onepassword-secrets = mkIf isDarwin {
      enable = true;
      tokenFile = "/etc/opnix-token";

      secrets = {
        # Linear API Token
        bugwarriorLinearToken = {
          reference = "op://Private/Linear Bugwarrior/credential";
          path = "${secretsDir}/bugwarrior-linear-token";
          owner = config.user.name;
          group = "staff";
          mode = "0600";
        };

        # Jira Credentials
        bugwarriorJiraUsername = {
          reference = "op://Work/Bugwarrior Jira/username";
          path = "${secretsDir}/bugwarrior-jira-username";
          owner = config.user.name;
          group = "staff";
          mode = "0600";
        };

        bugwarriorJiraPassword = {
          reference = "op://Work/Bugwarrior Jira/credential";
          path = "${secretsDir}/bugwarrior-jira-password";
          owner = config.user.name;
          group = "staff";
          mode = "0600";
        };

        # GitHub Personal Access Token (shared across all GitHub targets)
        bugwarriorGithubToken = {
          reference = "op://Private/GitHub Personal Access Token/token";
          path = "${secretsDir}/bugwarrior-github-token";
          owner = config.user.name;
          group = "staff";
          mode = "0600";
        };
      };
    };

    # Zsh aliases for bugwarrior commands
    modules.shell.zsh.rcFiles = [ "${configDir}/bugwarrior/aliases.zsh" ];

    # Symlink bugwarrior.toml to ~/.config/bugwarrior/
    home-manager.users.${config.user.name} = {
      xdg.configFile."bugwarrior/bugwarrior.toml".source =
        "${configDir}/bugwarrior/bugwarrior.toml";
    };
  };
}
