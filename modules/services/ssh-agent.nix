{ config, options, pkgs, lib, ... }:
with lib; {
  options.modules.services.ssh-agent = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.services.ssh-agent.enable {
    programs.ssh.startAgent = true;
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
