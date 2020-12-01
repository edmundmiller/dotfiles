{ config, options, pkgs, lib, ... }:

with lib;
with lib.my;
let cfg = config.modules.shell.nnn;
in {
  options.modules.shell.nnn = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [ nnn ];
    environment.variables = {
      NNN_PLUG = "f:finder;o:fzopen;p:mocplay;d:diffs;t:nmount;v:imgview";
    };
  };
}
