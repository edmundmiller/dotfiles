# modules/themes/stylix/default.nix
#
# Thin wrapper around nix-community/stylix that fits this repo's module
# pattern (modules.theme.stylix.*). Provides the knobs we actually need
# per host:
#
#   - enable / polarity
#   - base16Scheme: either a path (yaml from tinted-theming or our own),
#     an attrset, or just a `schemeName` like "catppuccin-mocha" resolved
#     against pkgs.base16-schemes
#   - image: required by stylix. If not provided we mint a solid-color PNG
#     from the scheme's base00 so hosts don't need to commit a wallpaper.
#   - fonts: monospace/sansSerif/serif/emoji with sane darwin-friendly
#     defaults (JetBrains Mono / DejaVu / Noto Color Emoji)
#   - targets.ghostty.enable: leave stylix's ghostty target on (true) so
#     terminal colors stay in sync with the rest of the theme. Hosts that
#     want to keep a hand-authored ghostty theme can flip this off.
#
# Stylix's nix-darwin module is wired into both darwin host module lists
# in flake.nix; this module just exposes the high-level knobs.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.theme.stylix;

  # Resolve base16Scheme from a friendly name (e.g. "catppuccin-mocha")
  # to a yaml file inside pkgs.base16-schemes.
  resolvedScheme =
    if cfg.base16Scheme != null then
      cfg.base16Scheme
    else if cfg.schemeName != null then
      "${pkgs.base16-schemes}/share/themes/${cfg.schemeName}.yaml"
    else
      null;

  # Mint a 1920x1080 solid-color PNG from a hex string (no leading '#').
  # Used as the stylix.image fallback so hosts don't need a real wallpaper.
  mkSolidImage =
    hex:
    pkgs.runCommand "stylix-solid-${hex}.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
      magick -size 1920x1080 xc:'#${hex}' "$out"
    '';

  resolvedImage = if cfg.image != null then cfg.image else mkSolidImage cfg.fallbackImageColor;
  resolvedPolarity = if cfg.polarity == "auto" then "either" else cfg.polarity;
in
{
  options.modules.theme.stylix = with types; {
    enable = mkBoolOpt false;

    polarity = mkOption {
      type = enum [
        "auto"
        "either"
        "dark"
        "light"
      ];
      default = "auto";
      description = ''
        Stylix polarity. `auto` is a friendly alias for Stylix's `either`,
        which lets Stylix choose the best light/dark polarity from the scheme.
      '';
    };

    schemeName = mkOption {
      type = nullOr str;
      default = null;
      example = "catppuccin-mocha";
      description = ''
        Name of a scheme inside `pkgs.base16-schemes` (omit the `.yaml`).
        Ignored if `base16Scheme` is set directly.
      '';
    };

    base16Scheme = mkOption {
      type = nullOr (oneOf [
        path
        str
        (attrsOf str)
      ]);
      default = null;
      description = ''
        Forwarded to `stylix.base16Scheme`. Accepts a path to a yaml scheme,
        a string path, or a base16 attrset.
      '';
    };

    image = mkOption {
      type = nullOr (either path str);
      default = null;
      description = ''
        Wallpaper / fallback color source. Required by stylix even on
        darwin (where there's no wallpaper target) for color extraction.
        If null, a solid PNG built from `fallbackImageColor` is used.
      '';
    };

    fallbackImageColor = mkOption {
      type = str;
      default = "1e1e2e"; # catppuccin mocha base
      description = ''
        Hex color (no `#`) used to mint the solid-color placeholder image
        when `image` is null.
      '';
    };

    fonts = {
      monospace = {
        package = mkOpt package pkgs.jetbrains-mono;
        name = mkOpt str "JetBrains Mono";
      };
      sansSerif = {
        package = mkOpt package pkgs.dejavu_fonts;
        name = mkOpt str "DejaVu Sans";
      };
      serif = {
        package = mkOpt package pkgs.dejavu_fonts;
        name = mkOpt str "DejaVu Serif";
      };
      emoji = {
        package = mkOpt package pkgs.noto-fonts-color-emoji;
        name = mkOpt str "Noto Color Emoji";
      };
      sizes = {
        terminal = mkOpt int 14;
        applications = mkOpt int 12;
        desktop = mkOpt int 11;
        popups = mkOpt int 11;
      };
    };

    targets = {
      ghostty.enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Whether stylix should drive ghostty colors. Disable on hosts
          that want to keep a hand-authored ghostty theme.
        '';
      };
    };
  };

  config = mkMerge [
    {
      # Keep Stylix package overlays disabled globally. With nix-darwin's
      # explicit `nixpkgs.pkgs`, the overlay modules can force config while pkgs
      # is still being evaluated and recurse before our wrapper options settle.
      stylix.overlays.enable = false;
    }

    (mkIf (cfg.enable && resolvedScheme == null) {
      assertions = [
        {
          assertion = false;
          message = "modules.theme.stylix.enable = true but neither base16Scheme nor schemeName was set.";
        }
      ];
    })

    (mkIf (cfg.enable && resolvedScheme != null) {
      stylix = {
        enable = true;
        polarity = resolvedPolarity;
        base16Scheme = resolvedScheme;
        image = resolvedImage;

        fonts = {
          monospace = { inherit (cfg.fonts.monospace) package name; };
          sansSerif = { inherit (cfg.fonts.sansSerif) package name; };
          serif = { inherit (cfg.fonts.serif) package name; };
          emoji = { inherit (cfg.fonts.emoji) package name; };
          sizes = {
            inherit (cfg.fonts.sizes)
              terminal
              applications
              desktop
              popups
              ;
          };
        };

        # Ghostty is a Home Manager target in Stylix. The nix-darwin module
        # wires Home Manager through `stylix.homeManagerIntegration`, so avoid
        # setting `stylix.targets.ghostty` at the Darwin/system level where the
        # option does not exist.
      };
    })
  ];
}
