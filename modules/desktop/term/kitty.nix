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
        macos_colorspace = "srgb";  # Default, matches web browsers

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

        # Shell integration - required for --cwd=current to work
        shell_integration = "enabled";

        # Remote control - stops directory approval prompts
        allow_remote_control = "yes";
      };
      extraConfig = ''
        # Font features - enable ligatures (synced from Ghostty)
        font_features Maple Mono NF +liga

        # Theme: Auto light/dark switching (kitty 0.38+)
        # Uses dark-theme.auto.conf and light-theme.auto.conf based on OS appearance

        ########################################
        # Tmux-Style Keybindings               #
        ########################################
        # Prefix: ctrl+c (matches tmux config, press twice to send SIGINT)
        # Based on: https://github.com/hlissner/dotfiles/blob/master/config/tmux/tmux.conf
        map ctrl+c>ctrl+c send_text all \x03

        ## Window/Tab Management
        map cmd+t launch --cwd=current --type=tab
        map ctrl+c>c launch --cwd=current --type=tab
        map ctrl+c>shift+n launch --cwd=current --type=os-window
        map ctrl+c>ctrl+n next_tab
        map ctrl+c>n next_tab
        map ctrl+c>ctrl+p previous_tab
        map ctrl+c>p previous_tab
        map ctrl+c>ctrl+w goto_tab -1
        map ctrl+c>1 goto_tab 1
        map ctrl+c>2 goto_tab 2
        map ctrl+c>3 goto_tab 3
        map ctrl+c>4 goto_tab 4
        map ctrl+c>5 goto_tab 5
        map ctrl+c>6 goto_tab 6
        map ctrl+c>7 goto_tab 7
        map ctrl+c>8 goto_tab 8
        map ctrl+c>9 goto_tab 9
        map ctrl+c>shift+w select_tab
        map ctrl+c>. select_tab
        map ctrl+c>shift+x close_tab

        ## Pane/Split Management
        # Note: kitty's vsplit/hsplit refer to split LINE direction, not window arrangement
        # vsplit = vertical line = windows side-by-side (horizontal arrangement)
        # hsplit = horizontal line = windows stacked (vertical arrangement)
        # We swap them so v=vertical stacking, s=side-by-side (more intuitive)
        map ctrl+c>v launch --cwd=current --location=hsplit
        map ctrl+c>s launch --cwd=current --location=vsplit
        map ctrl+c>h neighboring_window left
        map ctrl+c>j neighboring_window down
        map ctrl+c>k neighboring_window up
        map ctrl+c>l neighboring_window right
        map ctrl+c>x close_window
        map ctrl+c>o toggle_layout stack
        map ctrl+c>minus detach_window new-tab

        ## Layout Management
        map ctrl+c>shift+\ layout_action rotate
        map ctrl+c>equal reset_window_sizes

        ## Session Management
        map ctrl+c>shift+s goto_session
        map ctrl+c>/ goto_session
        map ctrl+c>d goto_session ~/.config/kitty/sessions/default.kitty-session
        map ctrl+c>m goto_session ~/.config/kitty/sessions/minimal.kitty-session
        map ctrl+c>ctrl+shift+p goto_session ~/.config/kitty/sessions/dev.kitty-session
        map ctrl+c>q close_os_window

        ## Copy Mode & Scrollback
        map ctrl+c>enter show_scrollback

        ## Misc/Utility
        map ctrl+c>r load_config_file
        map ctrl+c>ctrl+r clear_terminal reset active

        ## Resize (not in tmux config, but useful)
        map ctrl+c>left resize_window narrower
        map ctrl+c>right resize_window wider
        map ctrl+c>up resize_window taller
        map ctrl+c>down resize_window shorter

        ## Custom Project Creation (unique to your workflow)
        map ctrl+c>shift+1 kitten new_project.py 1
        map ctrl+c>shift+2 kitten new_project.py 2
        map ctrl+c>shift+3 kitten new_project.py 3

        ########################################
        # Session Display & Startup            #
        ########################################

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

      # Auto light/dark theme switching (kitty 0.38+)
      # These files are auto-detected by kitty based on OS appearance
      # Must use text content, not symlinks - kitty needs actual files in config dir
      "kitty/dark-theme.auto.conf".text = builtins.readFile catppuccinMocha;
      "kitty/light-theme.auto.conf".text = builtins.readFile catppuccinLatte;
      "kitty/no-preference-theme.auto.conf".text = builtins.readFile catppuccinMocha;
    };
  };
}
