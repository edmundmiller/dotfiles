{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents.plannotator;
  version = "0.28.66";
  piExtensionVersion = version;
  system = pkgs.stdenv.hostPlatform.system;
  releases = {
    aarch64-darwin = {
      asset = "plannotator-darwin-arm64";
      hash = "sha256-RKhrL3zXYsJY5QVVxmXPkziPyoqAWFabmREcPz8syQc=";
    };
    x86_64-darwin = {
      asset = "plannotator-darwin-x64";
      hash = "sha256-CwVVBDt/jrp2MQWRruEe28TvDTBwnZkZ/jwKZNP8gT4=";
    };
    aarch64-linux = {
      asset = "plannotator-linux-arm64";
      hash = "sha256-/aa37UhEUE/ezSs3CZHyZBgB3ZdLNRVb9KX84yj81cc=";
    };
    x86_64-linux = {
      asset = "plannotator-linux-x64";
      hash = "sha256-T99icfTahaudD6+l/BYFd4XZ9ASQIxkmFJrftbXFEMI=";
    };
  };
  release = releases.${system} or (throw "Plannotator does not publish a binary for ${system}");
  plannotator = pkgs.stdenvNoCC.mkDerivation {
    pname = "plannotator";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://github.com/backnotprop/plannotator/releases/download/v${version}/${release.asset}";
      inherit (release) hash;
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/plannotator"
      runHook postInstall
    '';
    meta = {
      description = "Visual review surface for coding-agent plans and diffs";
      homepage = "https://github.com/backnotprop/plannotator";
      license = with licenses; [
        asl20
        mit
      ];
      mainProgram = "plannotator";
      platforms = builtins.attrNames releases;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
    };
  };
  codexEnabled = config.modules.agents.codex.enable;
  piEnabled = config.modules.agents.pi.enable;
  herdrEnabled = config.modules.shell.herdr.enable;
  supportedAgentEnabled = piEnabled || herdrEnabled;
in
{
  options.modules.agents.plannotator = {
    enable = mkOption {
      type = types.bool;
      default = supportedAgentEnabled;
      defaultText = literalExpression ''
        config.modules.agents.pi.enable
        || config.modules.shell.herdr.enable
      '';
      description = "Install Plannotator and configure each enabled supported agent.";
    };
    package = mkOption {
      type = types.package;
      default = plannotator;
      description = "Pinned Plannotator package.";
    };
  };

  config = mkMerge [
    (mkIf codexEnabled {
      home-manager.users.${config.user.name} =
        { lib, ... }:
        {
          home.activation.plannotator-codex-cleanup =
            lib.hm.dag.entryAfter
              [
                "codex-config-bootstrap"
                "herdr-agent-integrations"
              ]
              ''
                ${pkgs.python3}/bin/python3 ${./cleanup_codex.py} \
                  --codex-hooks "$HOME/.codex/hooks.json"
              '';
        };
    })

    (mkIf cfg.enable {
      user.packages = [ cfg.package ];

      # Upstream registers the Inbox tool and reply wake only when opted in.
      env.PLANNOTATOR_INBOX_TOOL = "1";
      # Nix owns integrations and updates. Opening the Inbox must not add
      # Codex hooks or rewrite the host-owned MCP configuration.
      env.PLANNOTATOR_INBOX_CONNECT = "0";
      env.PLANNOTATOR_INBOX_NOTES = "0";
      env.PLANNOTATOR_AUTO_UPDATE = "0";

      # Hosts opt in with `modules.agents.mcp.servers.plannotator-inbox.enable`.
      # Pi already gets the Inbox tool from the Plannotator extension.
      modules.agents.mcp.servers.plannotator-inbox = {
        transport = mkDefault "stdio";
        command = mkDefault (getExe cfg.package);
        args = mkDefault [
          "inbox"
          "mcp"
        ];
        excludeAgents = mkDefault [ "pi" ];
      };

      modules.agents.pi.extraPackages = mkIf piEnabled [
        {
          source = "npm:@plannotator/pi-extension@${piExtensionVersion}";
          # The thin registrar loads at session start when Inbox is enabled;
          # otherwise it defers the package entrypoint until first use.
          extensions = [ ];
        }
      ];
    })
  ];
}
