# Headless Obsidian Sync via LinuxServer Docker container
#
# Setup (one-time, after first deploy):
# 1. SSH tunnel: ssh -L 3000:localhost:3000 nuc
# 2. Open http://localhost:3000 in browser
# 3. Click "Open folder as vault" -> select /config/vault
# 4. Settings -> Sync -> Log in to Obsidian account
# 5. Connect to existing remote vault
# 6. Wait for sync to complete
#
# Access vault via SSH: ssh nuc && cd ~/obsidian-vault
{
  options,
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.obsidian-sync;
in
{
  options.modules.services.obsidian-sync = {
    enable = mkBoolOpt false;
    vaultPath = mkOpt types.str "/home/emiller/obsidian-vault";
    user = mkOpt types.str "emiller";
  };

  # NixOS-only service (OCI containers)
  config = mkIf cfg.enable (optionalAttrs (!isDarwin) {
    # Enable podman for OCI containers
    virtualisation.podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    virtualisation.oci-containers.backend = "podman";

    # Enable unprivileged user namespaces for rootless podman containers
    boot.kernel.sysctl."kernel.unprivileged_userns_clone" = 1;

    # Ensure directories exist with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.vaultPath} 0755 ${cfg.user} users -"
      "d /home/${cfg.user}/.config/obsidian-headless 0755 ${cfg.user} users -"
    ];

    virtualisation.oci-containers.containers."obsidian-sync" = {
      autoStart = true;
      image = "lscr.io/linuxserver/obsidian:latest";
      ports = [
        "127.0.0.1:3000:3000" # Bind to localhost only - access via SSH tunnel
      ];
      volumes = [
        "/home/${cfg.user}/.config/obsidian-headless:/config:rw"
        "${cfg.vaultPath}:/config/vault:rw"
      ];
      environment = {
        PUID = "1000";
        PGID = "100";
        TZ = "America/Chicago";
      };
      extraOptions = [
        "--shm-size=1gb"
        "--security-opt=seccomp=unconfined"
      ];
    };
  });
}
