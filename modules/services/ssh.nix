{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.services.ssh;
in {
  options.modules.services.ssh = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    user.packages = with pkgs; [sshuttle];

    services.openssh = {
      enable = true;
      settings.kbdInteractiveAuthentication = false;
      settings.passwordAuthentication = false;
    };

    user.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFr8iZah3mwOy5QmDA/loQYBRspXooF2Fqaoq9kTAfuX edmuna.a.miller@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK3EVc3A55QHe83NXfqrClVohWz2DscDgx0pr4PSlcGO edmund.a.miller@protonmail.com"
    ];

    environment.shellAliases.utd = "sshuttle --dns -r pubssh 10.0.0.0/8 129.110.0.0/16";

    programs.ssh.extraConfig = ''
      Host pubssh
          HostName pubssh.utdallas.edu
          User eam150030

      Host europa
          HostName europa.trecis.cloud
          User emiller

      Host ganymede
          HostName ganymede.utdallas.edu
          User eam150030

      Host mz
          HostName mz.utdallas.edu
          User eam150030

      Host sysbio
          HostName sysbio.utdallas.edu
          User eam150030

      Host zhanggpu?
          HostName %h.utdallas.edu
          User eam150030

      Host mk
          HostName mk.utdallas.edu
          User eam150030

      Host promoter
          HostName promoter.utdallas.edu
          User emiller
    '';
  };
}
