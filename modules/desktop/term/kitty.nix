# modules/desktop/term/kitty.nix
{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.desktop.term.kitty;
in {
  options.modules.desktop.term.kitty = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    # kitty isn't supported over ssh, so revert to a known one
    environment.shellAliases = {s = "kitten ssh";};

    home-manager.users.${config.user.name}.programs.kitty = {
      enable = true;
      settings = {
        scrollback_lines = 10000;
        scrollback_pager = ''nvim -c 'setlocal nonumber nolist showtabline=0 foldcolumn=0|Man!' -c "autocmd VimEnter * normal G" -'';
        enable_audio_bell = false;
        update_check_interval = 0;
        hide_window_decorations = true;
      };
    };
  };
}
