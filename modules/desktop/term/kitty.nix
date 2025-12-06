# modules/desktop/term/kitty.nix
{
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.term.kitty;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.desktop.term.kitty = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # kitty isn't supported over ssh, so revert to a known one
    environment.shellAliases = {
      s = "kitten ssh";
    };

    home-manager.users.${config.user.name}.programs.kitty = {
      enable = true;
      settings = {
        scrollback_lines = 10000;
        scrollback_pager = ''nvim -c 'setlocal nonumber nolist showtabline=0 foldcolline=0|Man!' -c "autocmd VimEnter * normal G" -'';
        enable_audio_bell = false;
        update_check_interval = 0;
        notify_on_cmd_finish = "invisible 15.0";
        # linux_display_server = "wayland";  # Linux-only, commented out for macOS
        tab_bar_align = "left";

        # macOS-specific settings for native feel
        macos_titlebar_color = "system";
        macos_option_as_alt = "yes";
        macos_quit_when_last_window_closed = true;
        macos_show_window_title_in = "menubar";  # Show title in menubar (standard macOS)
        macos_traditional_fullscreen = false;
        macos_colorspace = "srgb";

        # Window appearance
        hide_window_decorations = "no";
        window_padding_width = 4;
        window_margin_width = 0;

        # Confirm close on quit
        confirm_os_window_close = 0;
      };
      extraConfig = ''
        # Session Management Keybindings (Ctrl+A prefix, tmux-style)
        # Save current layout to default session
        map ctrl+a>s save_as_session --use-foreground-process --relocatable ~/.config/kitty/sessions/default.kitty-session

        # Quick session switching
        map ctrl+a>d goto_session ~/.config/kitty/sessions/default.kitty-session
        map ctrl+a>m goto_session ~/.config/kitty/sessions/minimal.kitty-session
        map ctrl+a>p goto_session ~/.config/kitty/sessions/dev.kitty-session
        map ctrl+a>/ goto_session  # Browse all sessions
        map ctrl+a>- goto_session -1  # Previous session

        # Window/tab management
        map ctrl+a>enter launch --cwd=current --type=tab
        map ctrl+a>n new_tab_with_cwd
        map ctrl+a>w close_tab

        # Split windows
        map ctrl+a>minus launch --cwd=current --location=hsplit
        map ctrl+a>| launch --cwd=current --location=vsplit

        # Window navigation (vim-style)
        map ctrl+a>h neighboring_window left
        map ctrl+a>j neighboring_window down
        map ctrl+a>k neighboring_window up
        map ctrl+a>l neighboring_window right

        # Resize windows
        map ctrl+a>left resize_window narrower
        map ctrl+a>right resize_window wider
        map ctrl+a>up resize_window taller
        map ctrl+a>down resize_window shorter

        # Custom project creation kitten
        map ctrl+a>1 kitten new_project.py 1
        map ctrl+a>2 kitten new_project.py 2
        map ctrl+a>3 kitten new_project.py 3

        # Session display in tab bar
        tab_title_template {session_name} · {title}

        # Auto-restore default session on startup
        startup_session ~/.config/kitty/sessions/default.kitty-session
      '';
    };

    # Link session files and custom kitten
    home.configFile = {
      "kitty/sessions/default.kitty-session".source = "${configDir}/kitty/sessions/default.kitty-session";
      "kitty/sessions/minimal.kitty-session".source = "${configDir}/kitty/sessions/minimal.kitty-session";
      "kitty/sessions/dev.kitty-session".source = "${configDir}/kitty/sessions/dev.kitty-session";
      "kitty/sessions/project.kitty-session".source = "${configDir}/kitty/sessions/project.kitty-session";
      "kitty/new_project.py".source = "${configDir}/kitty/new_project.py";
    };
  };
}
