# modules/desktop/term/kitty.nix
{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.term.kitty;
  inherit (config.dotfiles) configDir;

  # Catppuccin theme files
  catppuccinMocha = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/catppuccin/kitty/main/themes/mocha.conf";
    hash = "sha256:094mj07fi3gq5j3gxgxh6aa7cxw8p3s6mfx4pczj8r1yqc0xvz4j";
  };
  catppuccinLatte = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/catppuccin/kitty/main/themes/latte.conf";
    hash = "sha256:137yfzqz09mnc8xis0cdxlz93jirgbh4j4cfcxzq1g8fg0n1v0jj";
  };
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
        # Font Configuration (synced from Ghostty)
        font_family = "Maple Mono NF";
        bold_font = "auto";
        italic_font = "auto";
        bold_italic_font = "auto";
        font_size = 14;

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
        macos_show_window_title_in = "menubar";  # Valid: menubar, titlebar, none
        macos_traditional_fullscreen = false;
        macos_colorspace = "displayp3";  # Match Ghostty's display-p3

        # Window appearance (synced from Ghostty)
        hide_window_decorations = "no";  # Show full native macOS titlebar
        window_padding_width = 8;  # Match Ghostty's 8px padding
        window_margin_width = 0;

        # Initial window size (synced from Ghostty)
        remember_window_size = false;
        initial_window_width = 1200;
        initial_window_height = 800;

        # TODO: Enable background opacity when Ghostty bug is fixed
        # https://github.com/ghostty-org/ghostty/issues/3049
        # background_opacity = 0.95;
        dynamic_background_opacity = true;

        # Confirm close on quit
        confirm_os_window_close = 0;
      };
      extraConfig = ''
        # Font features - enable ligatures (synced from Ghostty)
        font_features Maple Mono NF +liga

        # Theme: Catppuccin Mocha (dark)
        # TODO: Implement auto light/dark switching like Ghostty's
        # theme = light:Catppuccin Latte,dark:Catppuccin Mocha
        include themes/mocha.conf

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

    # Link session files, custom kitten, and themes
    home.configFile = {
      "kitty/sessions/default.kitty-session".source = "${configDir}/kitty/sessions/default.kitty-session";
      "kitty/sessions/minimal.kitty-session".source = "${configDir}/kitty/sessions/minimal.kitty-session";
      "kitty/sessions/dev.kitty-session".source = "${configDir}/kitty/sessions/dev.kitty-session";
      "kitty/sessions/project.kitty-session".source = "${configDir}/kitty/sessions/project.kitty-session";
      "kitty/new_project.py".source = "${configDir}/kitty/new_project.py";

      # Catppuccin themes (synced with Ghostty)
      "kitty/themes/mocha.conf".source = catppuccinMocha;
      "kitty/themes/latte.conf".source = catppuccinLatte;
    };
  };
}
