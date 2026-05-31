# Mosh — mobile shell for roaming/intermittent connectivity
# UDP-based, survives WiFi→cellular handoffs, sleep/wake, IP changes
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
  cfg = config.modules.services.mosh;
in
{
  options.modules.services.mosh = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Keep mosh-server on the system profile so Moshi's non-interactive SSH
      # bootstrap can find it without relying on login shell PATH setup.
      environment.systemPackages = [ pkgs.mosh ];

      # mosh client available in the user profile too.
      user.packages = [ pkgs.mosh ];

      # Moshi's host-side helpers are useful on every machine where mosh is
      # enabled: mosh keeps the connection alive, Moshi attaches users to the
      # durable tmux workspace when tmux is enabled on that host.
      modules.shell.moshi.enable = mkDefault true;
    }

    # NixOS: mosh server + firewall (UDP 60000-61000)
    (optionalAttrs (!isDarwin) {
      programs.mosh = {
        enable = true;
        openFirewall = true;
      };

      home-manager.users.${config.user.name}.systemd.user.services.moshi-hook = {
        Unit = {
          Description = "Moshi hook daemon";
          Documentation = [ "https://getmoshi.app" ];
          ConditionFileIsExecutable = "%h/.local/bin/moshi-hook";
        };

        Service = {
          ExecStart = "%h/.local/bin/moshi-hook serve";
          Restart = "always";
          RestartSec = 10;
        };

        Install.WantedBy = [ "default.target" ];
      };
    })
  ]);
}
