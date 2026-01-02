# modules/shell/bugwarrior.nix
# Bugwarrior configuration for syncing issues from GitHub, Linear, etc. to Taskwarrior
# Two flavors: personal (opnix/1Password) and work (manual file-based secrets)
#
# UDAs are tracked in git (union of all services)
# Regenerate on Seqeratop when adding services - see config/bugwarrior/UDAS.md
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
  # Secret paths for personal flavor (opnix/1Password)
  opnixSecretsDir = "/usr/local/var/opnix/secrets";
in
{
  options.modules.shell.bugwarrior = {
    enable = mkBoolOpt false;
    flavor = mkOption {
      type = types.enum [ "personal" "work" ];
      default = "personal";
      description = "Which bugwarrior configuration to use (personal or work)";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Bugwarrior requires taskwarrior
      modules.shell.taskwarrior.enable = true;

      # Zsh aliases for bugwarrior commands
      modules.shell.zsh.rcFiles = [ "${configDir}/bugwarrior/aliases.zsh" ];

      # Symlink appropriate bugwarrior.toml based on flavor
      home-manager.users.${config.user.name} = {
        xdg.configFile."bugwarrior/bugwarrior.toml".source =
          "${configDir}/bugwarrior/bugwarrior-${cfg.flavor}.toml";
      };
    }

    # Darwin-only: Configure opnix secrets service for personal flavor
    # Work flavor uses manual file-based secrets in ~/.config/bugwarrior/secrets/
    # Use optionalAttrs to prevent NixOS from seeing the Darwin-only option path
    (optionalAttrs (isDarwin && cfg.flavor == "personal") {
      services.onepassword-secrets = {
        enable = true;
        tokenFile = "/etc/opnix-token";

        secrets = {
          # Linear API Token
          bugwarriorLinearToken = {
            reference = "op://Private/Linear Bugwarrior/credential";
            path = "${opnixSecretsDir}/bugwarrior-linear-token";
            owner = config.user.name;
            group = "staff";
            mode = "0600";
          };

          # GitHub Personal Access Token
          bugwarriorGithubToken = {
            reference = "op://Private/GitHub Personal Access Token/token";
            path = "${opnixSecretsDir}/bugwarrior-github-token";
            owner = config.user.name;
            group = "staff";
            mode = "0600";
          };
        };
      };
    })
  ]);
}
