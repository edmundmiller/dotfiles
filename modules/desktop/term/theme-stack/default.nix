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
      description = "Catppuccin Ghostty with Herdr/Pi/Hunk adapters pinned explicitly.";
      ghosttyConfig = ''
        # Terminal theme stack: Catppuccin substrate for Ghostty; child TUIs are pinned below.
        theme = light:Catppuccin Latte,dark:Catppuccin Mocha
      '';
      ghosttyThemeFiles = { };
      herdr = {
        managePiTheme = false;
        themeVariant = "catppuccin-auto";
      };
      hunk = {
        dark = "catppuccin-mocha";
        light = "catppuccin-latte";
        config = "catppuccin-mocha";
        transparentBackground = false;
      };
    };

    seqera = {
      description = "Seqera Ghostty palette with matching Herdr/Pi adapters.";
      ghosttyConfig = ''
        # Terminal theme stack: Seqera substrate for Ghostty; child TUIs are pinned below.
        theme = light:SeqeraLight,dark:SeqeraDark
      '';
      ghosttyThemeFiles = {
        SeqeraDark = "${configDir}/ghostty/themes/SeqeraDark";
        SeqeraLight = "${configDir}/ghostty/themes/SeqeraLight";
      };
      herdr = {
        managePiTheme = true;
        piThemeVariant = "seqera";
        themeVariant = "seqera";
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
        Host-level terminal theme stack. This pins the Ghostty substrate and the
        Herdr, Pi, and Hunk adapters together instead of scattering polarity
        choices across their individual modules.
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

      modules.shell.herdr = mkIf config.modules.shell.herdr.enable (
        {
          managePiTheme = mkDefault stack.herdr.managePiTheme;
          themeVariant = mkDefault stack.herdr.themeVariant;
        }
        // optionalAttrs (stack.herdr ? piThemeVariant) {
          piThemeVariant = mkDefault stack.herdr.piThemeVariant;
        }
      );

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
