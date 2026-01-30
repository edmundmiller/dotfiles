{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.ssh;
  # onePassPath = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  onePassPath = "~/.1password/agent.sock";
in
{
  options.modules.services.ssh = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      user.packages = with pkgs; [ unstable.sshuttle ];

      environment.shellAliases.utd = "sshuttle --dns -r pubssh 10.0.0.0/8 129.110.0.0/16";

      programs.ssh.extraConfig = ''
        Host *
            IdentityAgent ${onePassPath}

        Host pubssh
            HostName pubssh.utdallas.edu
            User eam150030

        Host europa
            HostName europa.trecis.cloud
            User emiller

        Host ganymede
            HostName ganymede.utdallas.edu
            User eam150030

        Host juno
            HostName juno.hpcre.utdallas.edu
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
    }

    # NixOS-specific openssh configuration
    (optionalAttrs (!isDarwin) {
      services.openssh = {
        enable = true;
        settings.KbdInteractiveAuthentication = false;
        settings.PasswordAuthentication = false;
      };

      user.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBsb81evtCCcWSZcLbFaXWrAeCWFrPXPjUvjH4ZKbQC edmundmiller" # New Key
        "no-touch-required sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDvVosAjBisOM6GMdSjkxDUQpaf0LX8bmT+T/c7NX2AdAAAACnNzaDpnaXRodWI= edmundmiller"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFr8iZah3mwOy5QmDA/loQYBRspXooF2Fqaoq9kTAfuX edmuna.a.miller@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK3EVc3A55QHe83NXfqrClVohWz2DscDgx0pr4PSlcGO edmund.a.miller@protonmail.com"
      ];
    })
  ]);
}
