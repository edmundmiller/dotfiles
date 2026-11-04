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
  version = "0.28.10";
  piExtensionVersion = version;
  system = pkgs.stdenv.hostPlatform.system;
  releases = {
    aarch64-darwin = {
      asset = "plannotator-darwin-arm64";
      hash = "sha256-G2qOU+WHqKqOeyZbi0DFDVhFoUhyyI43O/T0OZddORQ=";
    };
    x86_64-darwin = {
      asset = "plannotator-darwin-x64";
      hash = "sha256-q23UxhcwjtoqaTW8zw7DC7DNx2r/M5zYDjbZ5Y7CyTg=";
    };
    aarch64-linux = {
      asset = "plannotator-linux-arm64";
      hash = "sha256-OAz9zN/Rq9FfeXumslm6bzvP11Xbl0FHC/9Jhie0wMM=";
    };
    x86_64-linux = {
      asset = "plannotator-linux-x64";
      hash = "sha256-2EpKOhZe+CqDF2X+pmwsjErVs7ys75hsgHM4uoDS8Ls=";
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
  ompEnabled = config.modules.agents.omp.enable;
  herdrEnabled = config.modules.shell.herdr.enable;
  supportedAgentEnabled = piEnabled || ompEnabled || herdrEnabled;
  ompCommand = lib.getExe config.modules.agents.omp.package;
in
{
  options.modules.agents.plannotator = {
    enable = mkOption {
      type = types.bool;
      default = supportedAgentEnabled;
      defaultText = literalExpression ''
        config.modules.agents.pi.enable
        || config.modules.agents.omp.enable
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

      modules.agents.pi.extraPackages = mkIf piEnabled [
        {
          source = "npm:@plannotator/pi-extension@${piExtensionVersion}";
          # The thin registrar loads at session start when Inbox is enabled;
          # otherwise it defers the package entrypoint until first use.
          extensions = [ ];
        }
      ];

      home-manager.users.${config.user.name} =
        { lib, ... }:
        {
          home.activation.omp-plannotator-plugin = lib.mkIf ompEnabled (
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              export PI_SKIP_VERSION_CHECK=1
              export PI_CONFIG_DIR=.omp
              export PI_CODING_AGENT_DIR="$HOME/.omp/agent"
              export PI_PERMISSION_SYSTEM_CONFIG_PATH="$HOME/.omp/agent/extensions/pi-permission-system/config.json"
              plannotator_dir="$HOME/.omp/plugins/node_modules/@plannotator/pi-extension"
              ${ompCommand} plugin uninstall @plannotator/pi-extension --json >/dev/null 2>&1 || true
              ${ompCommand} plugin install npm:@plannotator/pi-extension@${version} --force --json >/dev/null
              ${pkgs.gnugrep}/bin/grep -F 'import { Type } from "@earendil-works/pi-ai";' "$plannotator_dir/index.ts" >/dev/null
              ${pkgs.gnugrep}/bin/grep -F 'import { Key } from "@earendil-works/pi-tui";' "$plannotator_dir/index.ts" >/dev/null
              ${pkgs.gnused}/bin/sed -i \
                -e 's|import { Type } from "@earendil-works/pi-ai";|const { Type } = globalThis.__dotfilesOmpLazyPluginHost;|' \
                -e 's|import { Key } from "@earendil-works/pi-tui";|const { Key } = globalThis.__dotfilesOmpLazyPluginHost;|' \
                "$plannotator_dir/index.ts"
              ${pkgs.bun}/bin/bun build "$plannotator_dir/index.ts" \
                --outfile "$plannotator_dir/omp-lazy-bundle.js" \
                --target bun \
                --external @anthropic-ai/claude-agent-sdk \
                --external @earendil-works/pi-agent-core \
                --external @earendil-works/pi-coding-agent \
                --external @opencode-ai/sdk
            ''
          );
        };
    })
  ];
}
