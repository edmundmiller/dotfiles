{ config, options, pkgs, lib, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.shell.nnn;
  # archive = builtins.fetchurl {
  #   url = "https://github.com/jarun/nnn/releases/download/v3.5/nnn-v3.5.tar.gz";
  #   sha256 = "1ww18vvfjkvi36rcamw8kpix4bhk71w5bw9kmnh158crah1x8dp6";
  # };
in {
  options.modules.shell.nnn = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [ nnn ];

    environment.variables = {
      NNN_PLUG = "f:finder;o:fzopen;p:mocplay;d:diffs;t:nmount;v:imgview";
    };

    # FIXME getplugs works
    # curl -Ls https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs | sh
    # home.configFile = {
    #   "nnn/plugins" = {
    #     source = "${archive}/plugins/";
    #     recursive = true;
    #   };
    # };
  };
}
