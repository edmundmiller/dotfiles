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
  # macOS: 1Password only exposes the agent under Group Containers (spaces
  # require quoting). Linux: ~/.1password/agent.sock is the 1P convention.
  onePassPath =
    if isDarwin then
      ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''
    else
      "~/.1password/agent.sock";
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBsb81evtCCcWSZcLbFaXWrAeCWFrPXPjUvjH4ZKbQC edmundmiller" # New Key
    "no-touch-required sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDvVosAjBisOM6GMdSjkxDUQpaf0LX8bmT+T/c7NX2AdAAAACnNzaDpnaXRodWI= edmundmiller"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFr8iZah3mwOy5QmDA/loQYBRspXooF2Fqaoq9kTAfuX edmuna.a.miller@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK3EVc3A55QHe83NXfqrClVohWz2DscDgx0pr4PSlcGO edmund.a.miller@protonmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILKq5Pgw1Cj7sKCo13FuFBBKNvSNJvlN3ZObhF/EjGT0 iphone-moshi"
  ];
in
{
  options.modules.services.ssh = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      user.packages = with pkgs; [ unstable.sshuttle ];

      users.users.${config.user.name}.openssh.authorizedKeys.keys = authorizedKeys;

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

        # NUC server (Tailscale/MagicDNS)
        Host nuc
            HostName nuc.cinnamon-rooster.ts.net
            User emiller
            ForwardAgent yes
      '';
    }

    # Darwin: enable Remote Login for Moshi/SSH over Tailscale.
    (optionalAttrs isDarwin { services.openssh.enable = true; })

    # NixOS-specific openssh configuration
    (optionalAttrs (!isDarwin) {
      services.openssh = {
        enable = true;
        settings.KbdInteractiveAuthentication = false;
        settings.PasswordAuthentication = false;
      };
    })
  ]);
}
