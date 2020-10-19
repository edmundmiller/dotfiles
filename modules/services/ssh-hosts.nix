{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.dev.ssh-hosts;
in {
  options.modules.dev.ssh-hosts = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    programs.ssh.extraConfig = ''
      Host pubssh
          HostName pubssh.utdallas.edu
          User eam150030

      Host ganymede
          HostName ganymede.utdallas.edu
          User eam150030
          ProxyJump pubssh

      Host mz
          HostName mz.utdallas.edu
          User eam150030
          ProxyJump pubssh

      Host mk
          HostName mk.utdallas.edu
          User eam150030
          ProxyJump pubssh

      Host promoter
          HostName promoter.utdallas.edu
          User emiller
          ProxyJump pubssh
    '';
  };
}
