{ config, lib, pkgs, ... }:

{
  services.autorandr = {
    enable = true;
    defaultTarget = "main";
  };

  home-manager.users.emiller.programs.autorandr = {
    enable = true;
    hooks = {
      postswitch = {
        # "change-background" = readFile ./change-background.sh;
        "change-dpi" = ''
          case "$AUTORANDR_CURRENT_PROFILE" in
            mobile)
              DPI=110
              ;;
            home-dual)
              DPI=186
              ;;
            home-single)
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
        # "bspwm" = "${pkgs.bspwm}/bin/bspc wm --restart";
        "wallpaper" = "feh --bg-scale /home/emiller/.dotfiles/assets/wallpapers/functionalDNA_grey.png";
        "polybar" = "~/.config/polybar/launch.sh";
      };
    };
    profiles = {
      home-dual = {
        fingerprint = {
          DP-0 =
          "00ffffffffffff000daee71500000000081b0104952213780228659759548e271e505400000001010101010101010101010101010101b43b804a713834405036680058c11000001acd27804a713834405036680058c11000001a00000000000000000000000000000000000000000002000c47ff0b3c6e1314246e00000000b6";
          DP-1 =
          "00ffffffffffff001e6d095b84dc0700051c0104b53c22789f3035a7554ea3260f50542108007140818081c0a9c0d1c08100010101014dd000a0f0703e803020650c58542100001a286800a0f0703e800890650c58542100001a000000fd00283d878738010a202020202020000000fc004c4720556c7472612048440a2001d80203117144900403012309070783010000023a801871382d40582c450058542100001e565e00a0a0a029503020350058542100001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c8";
          HDMI-0 =
          "00ffffffffffff001e6d085b2d3a0000031c0103803c2278ea3035a7554ea3260f50542108007140818081c0a9c0d1c081000101010108e80030f2705a80b0588a0058542100001e04740030f2705a80b0588a0058542100001a000000fd00383d1e873c000a202020202020000000fc004c4720556c7472612048440a2001a7020330714d902220050403020161605d5e5f230907076d030c001000b83c20006001020367d85dc401788003e30f0006023a801871382d40582c450058542100001a565e00a0a0a029503020350058542100001a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000aa";
        };
        config = {
          DP-0 = { enable = false; };
          DP-2 = { enable = false; };
          DP-3 = { enable = false; };
          DP-4 = { enable = false; };
          DP-1 = {
            enable = true;
            primary = true;
            mode = "3840x2160";
            position = "0x0";
            rate = "60.00";
            # dpi = 182;
          };
          HDMI-0 = {
            enable = true;
            mode = "3840x2160";
            position = "3840x0";
            rate = "60.00";
            # dpi = 182;
          };
        };
        hooks.postswitch = ''
          bspc monitor DP-1 -d {1,2,3,4,5}
          bspc monitor HDMI-0 -d 6
        '';
      };

      home-single = {
        fingerprint = {
          DP-0 =
          "00ffffffffffff000daee71500000000081b0104952213780228659759548e271e505400000001010101010101010101010101010101b43b804a713834405036680058c11000001acd27804a713834405036680058c11000001a00000000000000000000000000000000000000000002000c47ff0b3c6e1314246e00000000b6";
          DP-1 =
          "00ffffffffffff001e6d095b84dc0700051c0104b53c22789f3035a7554ea3260f50542108007140818081c0a9c0d1c08100010101014dd000a0f0703e803020650c58542100001a286800a0f0703e800890650c58542100001a000000fd00283d878738010a202020202020000000fc004c4720556c7472612048440a2001d80203117144900403012309070783010000023a801871382d40582c450058542100001e565e00a0a0a029503020350058542100001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c8";
          HDMI-0 =
          "00ffffffffffff001e6d085b2d3a0000031c0103803c2278ea3035a7554ea3260f50542108007140818081c0a9c0d1c081000101010108e80030f2705a80b0588a0058542100001e04740030f2705a80b0588a0058542100001a000000fd00383d1e873c000a202020202020000000fc004c4720556c7472612048440a2001a7020330714d902220050403020161605d5e5f230907076d030c001000b83c20006001020367d85dc401788003e30f0006023a801871382d40582c450058542100001a565e00a0a0a029503020350058542100001a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000aa";
        };
        config = {
          DP-0 = { enable = false; };
          DP-2 = { enable = false; };
          DP-3 = { enable = false; };
          DP-4 = { enable = false; };
          DP-1 = {
            enable = true;
            primary = true;
            mode = "3840x2160";
            position = "0x0";
            rate = "60.00";
          };
        };
        hooks.postswitch = ''
          bspc monitor DP-1 -d {1,2,3,4,5}
        '';
      };

      mobile = {
        fingerprint = {
          DP-0 =
          "00ffffffffffff000daee71500000000081b0104952213780228659759548e271e505400000001010101010101010101010101010101b43b804a713834405036680058c11000001acd27804a713834405036680058c11000001a00000000000000000000000000000000000000000002000c47ff0b3c6e1314246e00000000b6";
        };
        config = {
          DP-2 = { enable = false; };
          DP-3 = { enable = false; };
          DP-4 = { enable = false; };
          DP-1 = { enable = false; };
          DP-0 = {
            enable = true;
            primary = true;
            mode = "1920x1080";
            position = "0x0";
            rate = "60.01";
          };
        };
        hooks.postswitch = ''
          bspc monitor DP-0 -d {1,2,3,4,5}
        '';
      };

      lab-single = {
        fingerprint = {
          DP-0 =
          "00ffffffffffff000daee71500000000081b0104952213780228659759548e271e505400000001010101010101010101010101010101b43b804a713834405036680058c11000001acd27804a713834405036680058c11000001a00000000000000000000000000000000000000000002000c47ff0b3c6e1314246e00000000b6";
          HDMI-0 =
          "00ffffffffffff004c2d450b32445a5a181b010380341d782a7dd1a45650a1280f5054bfef80714f81c0810081809500a9c0b3000101023a801871382d40582c450009252100001e011d007251d01e206e28550009252100001e000000fd00324b1e5111000a202020202020000000fc00533234443330300a2020202020018f020311b14690041f13120365030c001000011d00bc52d01e20b828554009252100001e8c0ad090204031200c4055000925210000188c0ad08a20e02d10103e9600092521000018000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000051";
        };
        config = {
          DP-0 = { enable = false; };
          DP-2 = { enable = false; };
          DP-3 = { enable = false; };
          DP-4 = { enable = false; };
          HDMI-0 = {
            enable = true;
            primary = true;
            mode = "1920x1080";
            position = "0x0";
            rate = "60.00";
          };
        };
        hooks.postswitch = ''
          bspc monitor HDMI-0 -d {1,2,3,4,5}
        '';
      };
    };
  };
}
