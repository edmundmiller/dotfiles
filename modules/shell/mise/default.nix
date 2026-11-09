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
  cfg = config.modules.shell.mise;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.mise = {
    enable = mkBoolOpt false;
    # nixpkgs' mise can trail a project's `min_version`, and the Nix toolchain
    # cannot link mise >= 2026.11 on macOS, so a Darwin host can take
    # Homebrew's mise instead.
    homebrew = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      user.packages = optional (!cfg.homebrew) pkgs.mise ++ [ pkgs.nushell ];

      modules.shell.zsh = {
        rcInit = ''
          eval "$(mise activate zsh)"
          _cache mise completion zsh; compdef _mise mise
        '';
        rcFiles = [ "${configDir}/mise/aliases.zsh" ];
      };

      home.configFile = {
        "mise" = {
          source = "${configDir}/mise";
          recursive = true;
        };
      }
      # Shims load the cwd's mise.toml first, so an untrusted checkout breaks every
      # shimmed tool. Older mise rejects the setting as unknown; Homebrew's mise is
      # already newer.
      // optionalAttrs (cfg.homebrew || versionAtLeast pkgs.mise.version "2026.11.2") {
        "mise/conf.d/settings.toml".text = ''
          [settings]
          activate_shims = false
        '';
      };
    }
    (optionalAttrs isDarwin (mkIf cfg.homebrew { homebrew.brews = [ "mise" ]; }))
  ]);
}
