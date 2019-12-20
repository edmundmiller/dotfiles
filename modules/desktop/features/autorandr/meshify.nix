{ config, lib, pkgs, ... }:

{
  services.autorandr = {
    enable = true;
    defaultTarget = "home-dual";
  };

  home-manager.users.emiller.programs.autorandr = {
    enable = true;
    hooks = {
      postswitch = {
        # "change-background" = readFile ./change-background.sh;
        "change-dpi" = ''
          case "$AUTORANDR_CURRENT_PROFILE" in
            home-dual)
              DPI=186
              ;;
            home-single)
              DPI=186
              ;;
            *)
              echo "Unknown profle: $AUTORANDR_CURRENT_PROFILE"
              exit 1
          esac

          echo "Xft.dpi: $DPI" | ${pkgs.xorg.xrdb}/bin/xrdb -merge
        '';
        "wallpaper" =
        "feh --bg-scale /etc/dotfiles/assets/wallpapers/functionalDNA_grey.png";
        "polybar" = "~/.config/polybar/launch.sh";
      };
    };
    profiles = {
      home-dual = {
        fingerprint = {
          DP-2 =
          "00ffffffffffff001e6d095b84dc0700051c0104b53c22789f3035a7554ea3260f50542108007140818081c0a9c0d1c08100010101014dd000a0f0703e803020650c58542100001a286800a0f0703e800890650c58542100001a000000fd00283d878738010a202020202020000000fc004c4720556c7472612048440a2001d80203117144900403012309070783010000023a801871382d40582c450058542100001e565e00a0a0a029503020350058542100001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c8";
          DP-4 =
          "00ffffffffffff001e6d095b2d3a0000031c0104b53c22789e3035a7554ea3260f50542108007140818081c0a9c0d1c08100010101014dd000a0f0703e803020650c58542100001a286800a0f0703e800890650c58542100001a000000fd00383d1e8738000a202020202020000000fc004c4720556c7472612048440a2001350203117144900403012309070783010000023a801871382d40582c450058542100001e565e00a0a0a029503020350058542100001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c8";
        };
        config = {
          DP-0 = { enable = false; };
          DP-3 = { enable = false; };
          HDMI-0 = { enable = false; };
          DP-2 = {
            enable = true;
            primary = true;
            mode = "3840x2160";
            position = "0x0";
            rate = "60.00";
            # dpi = 182;
          };
          DP-4 = {
            enable = true;
            mode = "3840x2160";
            position = "3840x0";
            rate = "60.00";
            # dpi = 182;
          };
        };
        hooks.postswitch = ''
          bspc monitor DP-2 -d {1,2,3,4,5}
          bspc monitor DP-4 -d 6
        '';
      };
    };
  };
}
