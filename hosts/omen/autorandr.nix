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
              MONITOR="DP-0"
              ;;
            lab)
              DPI=96
              ;;
            *)
              echo "Unknown profle: $AUTORANDR_CURRENT_PROFILE"
              exit 1
          esac

          echo "Xft.dpi: $DPI" | ${pkgs.xorg.xrdb}/bin/xrdb -merge
        '';
        "wallpaper" =
          "feh --bg-scale /etc/dotfiles/assets/wallpapers/functionalDNA_grey.png";
        "polybar" = "~/.config/polybar/run.sh";
      };
    };
    profiles = {
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
      lab = {
        fingerprint = {
          DP-0 =
            "00ffffffffffff000daee71500000000081b0104952213780228659759548e271e505400000001010101010101010101010101010101b43b804a713834405036680058c11000001acd27804a713834405036680058c11000001a00000000000000000000000000000000000000000002000c47ff0b3c6e1314246e00000000b6";
          DP-1 =
            "00ffffffffffff004c2d450b32445a5a161b010380341d782a7dd1a45650a1280f5054bfef80714f81c0810081809500a9c0b3000101023a801871382d40582c450009252100001e011d007251d01e206e28550009252100001e000000fd00324b1e5111000a202020202020000000fc00533234443330300a20202020200191020311b14690041f13120365030c001000011d00bc52d01e20b828554009252100001e8c0ad090204031200c4055000925210000188c0ad08a20e02d10103e9600092521000018000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000051";
          HDMI-0 =
            "00ffffffffffff004c2d450b32445a5a181b010380341d782a7dd1a45650a1280f5054bfef80714f81c0810081809500a9c0b3000101023a801871382d40582c450009252100001e011d007251d01e206e28550009252100001e000000fd00324b1e5111000a202020202020000000fc00533234443330300a2020202020018f020311b14690041f13120365030c001000011d00bc52d01e20b828554009252100001e8c0ad090204031200c4055000925210000188c0ad08a20e02d10103e9600092521000018000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000051";
        };
        config = {
          DP-0 = { enable = false; };
          DP-2 = { enable = false; };
          DP-3 = { enable = false; };
          DP-4 = { enable = false; };
          DP-1 = {
            enable = true;
            primary = true;
            mode = "1920x1080";
            position = "0x0";
            rate = "60.00";
            # dpi = 182;
          };
          HDMI-0 = {
            enable = true;
            mode = "1920x1080";
            position = "1920x0";
            rate = "60.00";
            # dpi = 182;
          };
        };
        hooks.postswitch = ''
          bspc monitor DP-1 -d {1,2,3,4,5}
          bspc monitor HDMI-0 -d 6
        '';
      };
      labMeeting = {
        fingerprint = {
          DP-0 =
            "00ffffffffffff000daee71500000000081b0104952213780228659759548e271e505400000001010101010101010101010101010101b43b804a713834405036680058c11000001acd27804a713834405036680058c11000001a00000000000000000000000000000000000000000002000c47ff0b3c6e1314246e00000000b6";
          HDMI-0 = ''
            00ffffffffffff00068c010001000000271801038010098cfa9c209c544f8f26215256afcf008180a94081c0a9c0950090408100b300023a801871382d40582c4500c48e2100001e023a801871382d40582c450010090000001e000000fd0018550f5c11000a202020202020000000fc0041542d484456532d52580a202001f902031ff14c010602840510151113141f202309070765030c001000830100000e1f008051001e304080370010090000001c662156aa51001e30468f330004030000001e283c80a070b0234030203600100a0000001a011d007251d01e206e28550010090000001e00000000000000000000000000000000000000000000000092
          '';
        };
        config = {
          DP-1 = { enable = false; };
          DP-2 = { enable = false; };
          DP-3 = { enable = false; };
          DP-4 = { enable = false; };
          DP-0 = {
            enable = true;
            primary = true;
            mode = "1920x1080";
            position = "0x0";
            rate = "60.00";
            # dpi = 182;
          };
          HDMI-0 = {
            enable = true;
            mode = "1920x1080";
            position = "1920x0";
            rate = "60.00";
            # dpi = 182;
          };
        };
        hooks.postswitch = ''
          bspc monitor DP-0 -d {1,2,3,4,5}
          bspc monitor HDMI-0 -d 6
        '';
      };
    };
  };
}
