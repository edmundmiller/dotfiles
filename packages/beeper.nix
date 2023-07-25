{
  appimageTools,
  fetchurl,
  ...
}: let
  name = "beeper";
  version = "3.65.19";
in
  appimageTools.wrapType2 {
    inherit name version;

    src = fetchurl {
      url = "https://download.beeper.com/linux/appImage/x64";
      hash = "sha256-OPtp0lXo4Xw0LQOR9CuOaDdd2+YhaBMjvgWlvbPU2cM=";
    };

    # extraPkgs = pkgs: with pkgs; [];

    meta = {
      homepage = "https://www.beeper.com/";
      description = "All your chats in one app. Yes, really.";
      # license = lib.licenses.mit;
      platforms = ["x86_64-linux"];
      maintainers = ["emiller88"];
    };
  }
