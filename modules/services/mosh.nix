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
  moshiHookVersion = "0.2.15";
  moshiHookAssets = {
    aarch64-darwin = {
      asset = "moshi-hook_Darwin_arm64.tar.gz";
      hash = "sha256-6IEdpKbQLeXff9LsMF/PEyQ9S/H0O6gKuGbLiITBotQ=";
    };
    aarch64-linux = {
      asset = "moshi-hook_Linux_arm64.tar.gz";
      hash = "sha256-OmMNAQADDorh6AwhD2ivw8F0UECixHUU2qhAj/VEVKE=";
    };
    x86_64-darwin = {
      asset = "moshi-hook_Darwin_x86_64.tar.gz";
      hash = "sha256-HTqnqlHOgiSbjsDEyD71vYxeB8DuZ36LmpFdGGuAV+A=";
    };
    x86_64-linux = {
      asset = "moshi-hook_Linux_x86_64.tar.gz";
      hash = "sha256-IjP08Esr04U6KfI1nbvV6rxmszMkYEUQaqUU5A+PfQI=";
    };
  };
  moshiHookAsset = moshiHookAssets.${pkgs.stdenv.hostPlatform.system};
  moshiHook = pkgs.stdenvNoCC.mkDerivation {
    pname = "moshi-hook";
    version = moshiHookVersion;

    src = pkgs.fetchurl {
      url = "https://cdn.getmoshi.app/hook/v${moshiHookVersion}/${moshiHookAsset.asset}";
      inherit (moshiHookAsset) hash;
    };

    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      install -Dm755 moshi-hook "$out/bin/moshi-hook"
      ln -s moshi-hook "$out/bin/moshi"
      runHook postInstall
    '';
  };
in
{
  options.modules.services.mosh = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Keep mosh-server on the system profile so Moshi's non-interactive SSH
      # bootstrap can find it without relying on login shell PATH setup.
      environment.systemPackages = [
        pkgs.mosh
        moshiHook
      ];

      # mosh client and Moshi helpers available in the user profile too.
      user.packages = [
        pkgs.mosh
        moshiHook
      ];

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
          ConditionFileNotEmpty = "%h/.local/state/moshi/secrets.json";
        };

        Service = {
          ExecStartPre = "-${moshiHook}/bin/moshi-hook install";
          ExecStart = "${moshiHook}/bin/moshi-hook serve";
          Restart = "always";
          RestartSec = 10;
        };

        Install.WantedBy = [ "default.target" ];
      };
    })
  ]);
}
