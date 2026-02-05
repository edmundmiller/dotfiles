{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.nushell;
in
{
  options.modules.shell.nushell = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    # NixOS-only: set default shell (option doesn't exist on Darwin)
    (optionalAttrs (!pkgs.stdenv.isDarwin) {
      users.defaultUserShell = lib.mkForce pkgs.nushellFull;
    })

    {

      user.packages = with pkgs; [
        atuin
        bat
        btop
        eza
        fd
        unstable.fzf
        navi
        unstable.ollama
        openai-whisper-cpp
        tailspin
        tldr
        cheat
        thefuck
        unstable.rclone
        ripgrep
        sd
        unstable.yazi
      ];

      home-manager.users.${config.user.name}.programs = {
        nushell = {
          enable = true;
          package = pkgs.nushellFull;
          # The config.nu can be anywhere you want if you like to edit your Nushell with Nu
          configFile.source = ../../config/nushell/config.nu;
          envFile.source = ../../config/nushell/env.nu;
          # for editing directly to config.nu
          extraConfig = ''
            let carapace_completer = {|spans|
            carapace $spans.0 nushell $spans | from json
            }
            $env.config = {
             show_banner: false,
             completions: {
             case_sensitive: false # case-sensitive completions
             quick: true    # set to false to prevent auto-selecting completions
             partial: true    # set to false to prevent partial filling of the prompt
             algorithm: "fuzzy"    # prefix or fuzzy
             external: {
             # set to false to prevent nushell looking into $env.PATH to find more suggestions
                 enable: true
             # set to lower can improve completion performance at the cost of omitting some options
                 max_results: 100
                 completer: $carapace_completer # check 'carapace_completer'
               }
             }
            }
          '';
          # TODO Add nu_scripts https://github.com/NixOS/nixpkgs/blob/nixos-23.11/pkgs/shells/nushell/nu_scripts/default.nix#L30
        };
        atuin.enable = true;
        atuin.enableNushellIntegration = true;
        atuin.package = pkgs.my.atuin;
        carapace.enable = true;
        carapace.enableNushellIntegration = true;
        # TODO if direnv
        direnv.enableNushellIntegration = true;
        skim.enable = true;

        starship = {
          enable = true;
          settings = {
            add_newline = false;
            character = {
              success_symbol = "[λ](bold green)";
              error_symbol = "[λ](bold red)";
            };
          };
        };
        yazi = {
          enable = true;
          # enableNushellIntegration = true;
        };
        zoxide.enable = true;
        zoxide.enableNushellIntegration = true;
      };
    }
  ]);
}
