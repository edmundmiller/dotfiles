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

    # Ensure directories exist with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.vaultPath} 0755 ${cfg.user} users -"
      "d /home/${cfg.user}/.config/obsidian-headless 0755 ${cfg.user} users -"
    ];

    virtualisation.oci-containers.containers."obsidian-sync" = {
      autoStart = true;
      image = "lscr.io/linuxserver/obsidian:latest";
      volumes = [
        "${cfg.vaultPath}:/config/vault:rw"
        "/home/${cfg.user}/.config/obsidian-headless:/config:rw"
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
