{ pkgs, ... }:
{
  services.autorandr = {
    enable = true;
    defaultTarget = "mobile";
  };

  home-manager.users.emiller.programs.autorandr = {
    enable = true;
    hooks = {
      postswitch = {
        # "change-background" = readFile ./change-background.sh;
        "change-dpi" = ''
          case "$AUTORANDR_CURRENT_PROFILE" in
            mobile)
              DPI=196
              MONITOR="eDP-1"
              NEW_GDK_SCALE=2
              NEW_GDK_DPI_SCALE=0.5
              ;;
            lab)
              DPI=138
              MONITOR="DP-2-1"
              NEW_GDK_SCALE=2
              NEW_GDK_DPI_SCALE=0.5
              ;;
            home)
              DPI=140
              MONITOR="DP-3-3"
              NEW_GDK_SCALE=2
              NEW_GDK_DPI_SCALE=0.5
              ;;
            *)
              echo "Unknown profle: $AUTORANDR_CURRENT_PROFILE"
              exit 1
          esac

          echo "Xft.dpi: $DPI" | ${pkgs.xorg.xrdb}/bin/xrdb -merge
          export GDK_SCALE=$NEW_GDK_SCALE
          export GDK_DPI_SCALE=$NEW_GDK_DPI_SCALE

          source ~/.config/bspwm/bspwmrc
          for file in $XDG_CONFIG_HOME/bspwm/rc.d/*; do
            source "$file"
          done
        '';
        "wallpaper" = "feh --bg-scale /etc/nixos/modules/themes/functional/config/wallpaper.png";
        "polybar" = "~/.config/polybar/run.sh";
      };
    };
    profiles = {
      mobile = {
        fingerprint = {
          eDP-1 = "00ffffffffffff0009e55f0900000000171d0104a51c137803de50a3544c99260f505400000001010101010101010101010101010101115cd01881e02d50302036001dbe1000001aa749d01881e02d50302036001dbe1000001a000000fe00424f452043510a202020202020000000fe004e4531333546424d2d4e34310a00fb";
        };
        config = {
          DP-2 = {
            enable = false;
          };
          DP-3 = {
            enable = false;
          };
          DP-4 = {
            enable = false;
          };
          DP-1 = {
            enable = false;
          };
          eDP-1 = {
            enable = true;
            primary = true;
            mode = "2256x1504";
            position = "0x0";
            rate = "60.00";
          };
        };
      };
      lab = {
        fingerprint = {
          DP-3 = "00ffffffffffff001e6d50776de308000c1f0104b5462878fa7ba1ae4f44a9260c5054210800d1c061400101010101010101010101014dd000a0f0703e8030203500b9882100001a000000fd00283c1e873c000a202020202020000000fc004c472048445220344b0a202020000000ff003131324e545a4e48343530390a01d402031f7223090707830100004401030410e2006ae305c000e606050159595204740030f2705a80b0588a00b9882100001e565e00a0a0a0295030203500b9882100001a1a3680a070381f402a263500b9882100001a000000000000000000000000000000000000000000000000000000000000000000000000000000000000ea";
          eDP-1 = "00ffffffffffff0009e55f0900000000171d0104a51c137803de50a3544c99260f505400000001010101010101010101010101010101115cd01881e02d50302036001dbe1000001aa749d01881e02d50302036001dbe1000001a000000fe00424f452043510a202020202020000000fe004e4531333546424d2d4e34310a00fb";
        };
        config = {
          DP-3 = {
            enable = true;
            primary = true;
            mode = "3840x2160";
            position = "0x0";
            rate = "60.00";
          };
          eDP-1.enable = false;
        };
      };
      home = {
        fingerprint = {
          DP-3-3 = "00ffffffffffff001c54043201010101011e0103804627783ae1b5ad5045a0250d5054bfcf00714f81c081408180d1c0d1fc9500b30008e80030f2705a80b0588a00b9882100001a000000ff000a202020202020202020202020000000fd0030901eff83000a202020202020000000fc004769676162797465204d33325502ea020360f2565d5e5f6061014003111213040e0f1d1e1f903f75762f23090707830100006d030c001000383c2000600102036dd85dc40178c0330f3090c3340c6d1a0000020b3090e605653c653ce305c301e40f180018e6060501656512e200d56fc200a0a0a0555030203500b9882100001a00000000000000000000000000267012790000030150b9fd0184ff0e4f0007001f006f08990045000700eba30104ff0e4f0007001f006f087e0070000700fb7e00047f07870017801f003704110002800400555e0004ff099f002f801f009f052800028004000000000000000000000000000000000000000000000000000000000000000000000000000000f790";
          eDP-1 = "00ffffffffffff0009e55f0900000000171d0104a51c137803de50a3544c99260f505400000001010101010101010101010101010101115cd01881e02d50302036001dbe1000001aa749d01881e02d50302036001dbe1000001a000000fe00424f452043510a202020202020000000fe004e4531333546424d2d4e34310a00fb";
        };
        config = {
          DP-3-3 = {
            enable = true;
            primary = true;
            mode = "3840x2160";
            position = "0x0";
          };
          eDP-1.enable = false;
        };
      };
    };
  };
}
