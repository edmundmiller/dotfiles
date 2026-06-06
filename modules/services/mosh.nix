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
  moshiHookVersion = "0.2.22";
  moshiHookAssets = {
    aarch64-darwin = {
      asset = "moshi-hook_Darwin_arm64.tar.gz";
      hash = "sha256-Yk8b0Xy6D4MFV9MR9eyqXHJaOABeFyoM1HBgrBwP0gM=";
    };
    aarch64-linux = {
      asset = "moshi-hook_Linux_arm64.tar.gz";
      hash = "sha256-gNSDuPzYY1s0iGIsabbG0ok8HXTunwAKO5LwFrTxmRM=";
    };
    x86_64-darwin = {
      asset = "moshi-hook_Darwin_x86_64.tar.gz";
      hash = "sha256-rae86UXMvk7EiRtXG70HYNrdUaVeHT1Cj4WyTwyMwJA=";
    };
    x86_64-linux = {
      asset = "moshi-hook_Linux_x86_64.tar.gz";
      hash = "sha256-x7ung32Aqib9V9dY4vbtWXsmxTILKMIv9QZiEQccxak=";
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
    hookSecretsFile = mkOpt' (types.nullOr types.path) null ''
      Optional secrets.json file for the moshi-hook daemon. When null, only
      mosh server/client packages are installed and no hook daemon is enabled.
    '';
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
    })

    # Hosts with Moshi pairing secrets: user daemon + agent hook installation.
    (optionalAttrs (!isDarwin) (
      mkIf (cfg.hookSecretsFile != null) {
        home-manager.users.${config.user.name}.systemd.user.services.moshi-hook = {
          Unit = {
            Description = "Moshi hook daemon";
            Documentation = [ "https://getmoshi.app" ];
            ConditionFileNotEmpty = cfg.hookSecretsFile;
          };

          Service = {
            ExecStartPre = [
              "${pkgs.coreutils}/bin/mkdir -p %h/.local/state/moshi"
              "${pkgs.coreutils}/bin/install -m 600 ${cfg.hookSecretsFile} %h/.local/state/moshi/secrets.json"
              "-${moshiHook}/bin/moshi-hook install"
            ];
            ExecStart = "${moshiHook}/bin/moshi-hook serve";
            Restart = "always";
            RestartSec = 10;
          };

          Install.WantedBy = [ "default.target" ];
        };
      }
    ))
  ]);
}
