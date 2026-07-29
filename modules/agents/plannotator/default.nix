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
  version = "0.25.0";
  piExtensionVersion = "0.24.2";
  system = pkgs.stdenv.hostPlatform.system;
  releases = {
    aarch64-darwin = {
      asset = "plannotator-darwin-arm64";
      hash = "sha256-vE2lsaTytLw3792Mch+mZ5CGqpNSNu3r7mPK/EdIL+Q=";
    };
    x86_64-darwin = {
      asset = "plannotator-darwin-x64";
      hash = "sha256-4RWo0suCR/Gz40odw9SNNW8vl0GlqyhxJ07WLNMJ9GU=";
    };
    aarch64-linux = {
      asset = "plannotator-linux-arm64";
      hash = "sha256-ITAmPi44yZtTY5xeKs4AZjgzYcWN69ei2tO6hZPbar0=";
    };
    x86_64-linux = {
      asset = "plannotator-linux-x64";
      hash = "sha256-eXhaNzx3312fp90UbT4s2o4H3d20PnrS8U+bORwTUyU=";
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
  claudeEnabled = config.modules.agents.claude.enable;
  piEnabled = config.modules.agents.pi.enable;
  ompEnabled = config.modules.agents.omp.enable;
  herdrEnabled = config.modules.shell.herdr.enable;
  supportedAgentEnabled = codexEnabled || claudeEnabled || piEnabled || ompEnabled || herdrEnabled;
  command = lib.getExe cfg.package;
  ompCommand = lib.getExe config.modules.agents.omp.package;
in
{
  options.modules.agents.plannotator = {
    enable = mkOption {
      type = types.bool;
      default = supportedAgentEnabled;
      defaultText = literalExpression ''
        config.modules.agents.codex.enable
        || config.modules.agents.claude.enable
        || config.modules.agents.pi.enable
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

  config = mkIf cfg.enable {
    user.packages = [ cfg.package ];

    modules.agents.pi.extraPackages = mkIf piEnabled [
      "npm:@plannotator/pi-extension@${piExtensionVersion}"
    ];

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.activation.plannotator-codex = lib.mkIf codexEnabled (
          lib.hm.dag.entryAfter
            [
              "codex-config-bootstrap"
              "herdr-agent-integrations"
            ]
            ''
              ${pkgs.python3}/bin/python3 ${./configure.py} \
                --codex-config "$HOME/.codex/config.toml" \
                --codex-hooks "$HOME/.codex/hooks.json" \
                --command ${lib.escapeShellArg command}
            ''
        );

        home.activation.plannotator-claude-plugin = lib.mkIf claudeEnabled (
          lib.hm.dag.entryAfter
            [
              "claude-settings-bootstrap"
              "herdr-agent-integrations"
            ]
            ''
              claude_cmd=${lib.escapeShellArg "${pkgs.llm-agents.claude-code}/bin/claude"}
              if ! "$claude_cmd" plugin list --json \
                | ${pkgs.gnugrep}/bin/grep -F '"id": "plannotator@plannotator"' >/dev/null; then
                if ! "$claude_cmd" plugin marketplace list --json \
                  | ${pkgs.gnugrep}/bin/grep -F '"name": "plannotator"' >/dev/null; then
                  "$claude_cmd" plugin marketplace add backnotprop/plannotator
                fi
                "$claude_cmd" plugin install --scope user plannotator@plannotator
              fi
            ''
        );

        home.activation.omp-plannotator-plugin = lib.mkIf ompEnabled (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            export PI_SKIP_VERSION_CHECK=1
            export PI_CONFIG_DIR=.omp
            export PI_CODING_AGENT_DIR="$HOME/.omp/agent"
            export PI_PERMISSION_SYSTEM_CONFIG_PATH="$HOME/.omp/agent/extensions/pi-permission-system/config.json"
            ${ompCommand} plugin uninstall @plannotator/pi-extension --json >/dev/null 2>&1 || true
            ${ompCommand} plugin install npm:@plannotator/pi-extension@${version} --force --json >/dev/null
          ''
        );
      };
  };
}
