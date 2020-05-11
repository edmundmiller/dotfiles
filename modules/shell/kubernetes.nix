{ config, options, pkgs, lib, ... }:
with lib; {
  options.modules.shell.kubernetes = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.shell.kubernetes.enable {
    my = {
      packages = with pkgs; [ kubectl unstable.kubernetes-helm k9s ];

      alias.k = "kubectl";
    };
  };
}
