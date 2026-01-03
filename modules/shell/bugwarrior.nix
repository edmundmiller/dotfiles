# modules/shell/bugwarrior.nix
# Bugwarrior configuration for syncing issues from GitHub, Linear, etc. to Taskwarrior
# Two flavors: personal (opnix/1Password) and work (manual file-based secrets)
#
# FIXME: This module is Darwin-only due to opnix/1Password integration.
# To support NixOS, we need to either:
# 1. Use agenix for secrets on NixOS (similar to taskwarrior sync)
# 2. Use a different secrets backend (sops-nix, etc.)
# 3. Support manual file-based secrets for NixOS (work flavor approach)
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

  # FIXME: Use mkMerge with optionalAttrs to completely hide Darwin-only options from NixOS
  # The mkIf pattern doesn't work because NixOS still tries to evaluate the option path
  config = mkIf (cfg.enable && isDarwin) (mkMerge [
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

    # Configure opnix secrets service for personal flavor only
    # Work flavor uses manual file-based secrets in ~/.config/bugwarrior/secrets/
    (mkIf (cfg.flavor == "personal") {
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
