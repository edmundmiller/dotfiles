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
  moshiHookVersion = "0.2.26";
  moshiHookAssets = {
    aarch64-darwin = {
      asset = "moshi-hook_Darwin_arm64.tar.gz";
      hash = "sha256-Ur0DIdGTYy8ArrPm0saBqDwZ7O1WtQrDNzsE7NyWSqI=";
    };
    aarch64-linux = {
      asset = "moshi-hook_Linux_arm64.tar.gz";
      hash = "sha256-RmsSF8URIrQEdG7FwdXoW0VyqQ7Sk88AKTRbNSZU2Ww=";
    };
    x86_64-darwin = {
      asset = "moshi-hook_Darwin_x86_64.tar.gz";
      hash = "sha256-OWbRFPsJwf6h2tAd3Ivs1SQCneSrS7a0uH83GZ1FCSA=";
    };
    x86_64-linux = {
      asset = "moshi-hook_Linux_x86_64.tar.gz";
      hash = "sha256-kl3aazpQ1o05k/MoJFugv7CcGJG4vUTArpMQcbzbvgM=";
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

  config = mkMerge [
    # The Moshi hook helper is needed for native Pi hook installation on Darwin
    # hosts even when they do not otherwise enable mosh transport/server support.
    (mkIf (cfg.enable || (isDarwin && config.modules.agents.pi.enable)) {
      environment.systemPackages = [ moshiHook ];
      user.packages = [ moshiHook ];

      # Moshi's shell module owns agent hook installation. It auto-links hooks
      # for agent modules enabled on this host, while this service module only
      # ensures the moshi-hook binary is present when Moshi/Pi needs it.
      modules.shell.moshi.enable = mkDefault true;
    })

    (mkIf cfg.enable {
      # Keep mosh-server on the system profile so Moshi's non-interactive SSH
      # bootstrap can find it without relying on login shell PATH setup.
      environment.systemPackages = [ pkgs.mosh ];

      # mosh client available in the user profile too.
      user.packages = [ pkgs.mosh ];
    })

    # NixOS: mosh server + firewall (UDP 60000-61000)
    (optionalAttrs (!isDarwin) (
      mkIf cfg.enable {
        programs.mosh = {
          enable = true;
          openFirewall = true;
        };
      }
    ))

    # Hosts with Moshi pairing secrets: user daemon + agent hook installation.
    (optionalAttrs (!isDarwin) (
      mkIf (cfg.enable && cfg.hookSecretsFile != null) {
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
  ];
}
