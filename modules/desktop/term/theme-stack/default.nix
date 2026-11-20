{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.term.themeStack;
  inherit (config.dotfiles) configDir;

  stacks = {
    catppuccin = {
      description = "Catppuccin Ghostty palette with explicit Hunk light/dark themes.";
      ghosttyConfig = ''
        # Terminal theme stack: Catppuccin substrate for Ghostty; child TUIs are pinned below.
        theme = light:Catppuccin Latte,dark:Catppuccin Mocha
      '';
      ghosttyThemeFiles = { };
      hunk = {
        dark = "catppuccin-mocha";
        light = "catppuccin-latte";
        config = "catppuccin-mocha";
        transparentBackground = false;
      };
    };

    seqera = {
      description = "Seqera Ghostty palette with explicit Hunk light/dark themes.";
      ghosttyConfig = ''
        # Select the repository's paired light/dark palettes directly.
        theme = light:${configDir}/ghostty/themes/SeqeraLight,dark:${configDir}/ghostty/themes/SeqeraDark
      '';
      ghosttyThemeFiles = {
        SeqeraDark = "${configDir}/ghostty/themes/SeqeraDark";
        SeqeraLight = "${configDir}/ghostty/themes/SeqeraLight";
      };
      hunk = {
        # Hunk has no Seqera palette; keep the child TUI polarity explicit.
        dark = "catppuccin-mocha";
        light = "catppuccin-latte";
        config = "catppuccin-mocha";
        transparentBackground = false;
      };
    };
  };

  stack = stacks.${cfg.variant};
  ghosttyThemeLinks = mapAttrs' (
    name: source: nameValuePair "ghostty/themes/${name}" { inherit source; }
  ) stack.ghosttyThemeFiles;

  hunkGhosttyEnv =
    optionalString
      (config.modules.shell.git.hunk.enable && config.modules.shell.git.hunk.theme.dark != null)
      ''
        env=HUNK_THEME_DARK=${config.modules.shell.git.hunk.theme.dark}
      ''
    +
      optionalString
        (config.modules.shell.git.hunk.enable && config.modules.shell.git.hunk.theme.light != null)
        ''
          env=HUNK_THEME_LIGHT=${config.modules.shell.git.hunk.theme.light}
        '';
in
{
  options.modules.desktop.term.themeStack = with types; {
    enable = mkBoolOpt false;
    variant = mkOption {
      type = enum (attrNames stacks);
      default = "catppuccin";
      description = ''
        Host-level Ghostty palette and Hunk light/dark themes.
        Native Herdr and Pi own their theme selection independently.
      '';
    };
    description = mkOption {
      type = str;
      readOnly = true;
      default = stack.description;
      description = "Human-readable description of the active terminal theme stack.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      modules.desktop.term.ghostty.configInit = mkAfter (stack.ghosttyConfig + hunkGhosttyEnv);

      modules.shell.git.hunk.theme = mkIf config.modules.shell.git.hunk.enable {
        dark = mkDefault stack.hunk.dark;
        light = mkDefault stack.hunk.light;
        config = mkDefault stack.hunk.config;
        transparentBackground = mkDefault stack.hunk.transparentBackground;
      };

      environment.variables = mkIf config.modules.shell.git.hunk.enable (
        optionalAttrs (config.modules.shell.git.hunk.theme.dark != null) {
          HUNK_THEME_DARK = config.modules.shell.git.hunk.theme.dark;
        }
        // optionalAttrs (config.modules.shell.git.hunk.theme.light != null) {
          HUNK_THEME_LIGHT = config.modules.shell.git.hunk.theme.light;
        }
      );
    }

    (mkIf (config.modules.desktop.term.ghostty.enable && ghosttyThemeLinks != { }) {
      home-manager.users.${config.user.name}.xdg.configFile = ghosttyThemeLinks;
    })
  ]);
}
