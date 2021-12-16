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
              DPI=196
              MONITOR="eDP-1"
              ;;
            lab)
              DPI=144
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
          eDP-1 =
            "00ffffffffffff0009e55f0900000000171d0104a51c137803de50a3544c99260f505400000001010101010101010101010101010101115cd01881e02d50302036001dbe1000001aa749d01881e02d50302036001dbe1000001a000000fe00424f452043510a202020202020000000fe004e4531333546424d2d4e34310a00fb";
        };
        config = {
          DP-2 = { enable = false; };
          DP-3 = { enable = false; };
          DP-4 = { enable = false; };
          DP-1 = { enable = false; };
          eDP-1 = {
            enable = true;
            primary = true;
            mode = "2256x1504";
            position = "0x0";
            rate = "60.00";
          };
        };
        hooks.postswitch = ''
          bspc monitor eDP-1 -d {1,2,3,4,5}
        '';
      };
      lab = {
        fingerprint = {
          eDP-1 =
            "00ffffffffffff0009e55f0900000000171d0104a51c137803de50a3544c99260f505400000001010101010101010101010101010101115cd01881e02d50302036001dbe1000001aa749d01881e02d50302036001dbe1000001a000000fe00424f452043510a202020202020000000fe004e4531333546424d2d4e34310a00fb";
          DP-2-1 =
            "00ffffffffffff001e6df1591b6804000a1b010380502278eaca95a6554ea1260f5054a54b80714f818081c0a9c0b3000101010101017e4800e0a0381f4040403a001e4e31000018023a801871382d40582c45001e4e3100001e000000fc004c4720554c545241574944450a000000fd00384b1e5a18000a202020202020017802031df14a900403220012001f0113230907078301000065030c001000023a801871382d40582c450056512100001e000000000000000000000000000000000000011d007251d01e206e28550056512100001e8c0ad08a20e02d10103e9600565121000018000000ff003731304e544d5838473739350a00000000000000000d";
        };
        config = {
          eDP-1 = { enable = false; };
          DP-2 = { enable = false; };
          DP-4 = { enable = false; };
          DP-1 = { enable = false; };
          HDMI-0 = { enable = false; };
          DP-2-1 = {
            enable = true;
            primary = true;
            mode = "2560x1080";
            position = "0x0";
            rate = "60.00";
          };
        };
        hooks.postswitch = ''
          source ~/.config/bspwm/bspwmrc
        '';
      };
    };
  };
}
