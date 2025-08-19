{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.git;
in
{
  options.modules.shell.git = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      git-open
      difftastic
      (mkIf config.modules.shell.gnupg.enable git-crypt)
      git-lfs
      pre-commit
    ];

    # Use home-manager's programs.git for better integration
    home-manager.users.${config.user.name} = {
      programs.git = {
        enable = true;
        package = pkgs.git;
        
        # Include the main config file which has all settings
        includes = [
          { path = "${configDir}/git/config"; }
        ];
        
        # Set up the ignore file
        ignores = lib.splitString "\n" (builtins.readFile "${configDir}/git/ignore");
        
        # Fix the SSH signing program path
        extraConfig = {
          gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
        };
      };
      
      # Also create direct symlinks for git config files
      # This ensures they're available at the expected paths
      xdg.configFile = {
        "git/allowed_signers".source = "${configDir}/git/allowed_signers";
      };
    };

    modules.shell.zsh.rcFiles = [ "${configDir}/git/aliases.zsh" ];
  };
}
