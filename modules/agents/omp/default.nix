{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents.omp;
  inherit (config.dotfiles) configDir;
  ompConfigDir = "${config.user.home}/.omp";
  ompAgentDir = "${ompConfigDir}/agent";
  nextflowLanguageServer = pkgs.writeShellScriptBin "nextflow-language-server" ''
    # Launcher for the official Nextflow language server.
    #
    # Resolution order:
    #   1. nlsp on the caller PATH
    #   2. $NEXTFLOW_LSP_JAR
    #   3. downloaded language-server-all.jar cached under ~/.nextflow/lsp
    #
    # The GitHub release selection mirrors nextflow-io/agent-skills#12.
    set -euo pipefail

    java_bin="${pkgs.jdk}/bin/java"
    curl_bin="${pkgs.curl}/bin/curl"
    grep_bin="${pkgs.gnugrep}/bin/grep"
    sed_bin="${pkgs.gnused}/bin/sed"
    sort_bin="${pkgs.coreutils}/bin/sort"
    tail_bin="${pkgs.coreutils}/bin/tail"
    ls_bin="${pkgs.coreutils}/bin/ls"
    mkdir_bin="${pkgs.coreutils}/bin/mkdir"
    mv_bin="${pkgs.coreutils}/bin/mv"

    minor="''${NEXTFLOW_LSP_VERSION:-26.04}"
    prefix="v''${minor}"
    prefix_re="$(printf '%s' "$prefix" | "$sed_bin" 's/\./\\./g')"

    log() { echo "nextflow-language-server: $*" >&2; }

    if command -v nlsp >/dev/null 2>&1; then
      exec nlsp "$@"
    fi

    jar="''${NEXTFLOW_LSP_JAR:-}"

    if [ -z "$jar" ]; then
      cache_dir="''${HOME}/.nextflow/lsp/''${prefix}"
      api="https://api.github.com/repos/nextflow-io/language-server/releases"

      if [ -n "''${GITHUB_TOKEN:-}" ]; then
        releases="$("$curl_bin" -fsSL -H "Authorization: Bearer ''${GITHUB_TOKEN}" -H 'Accept: application/vnd.github.v3+json' "$api" 2>/dev/null || true)"
      else
        releases="$("$curl_bin" -fsSL -H 'Accept: application/vnd.github.v3+json' "$api" 2>/dev/null || true)"
      fi

      resolved=""
      if [ -n "$releases" ]; then
        best_patch="$(printf '%s' "$releases" \
          | "$grep_bin" -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
          | "$sed_bin" 's/.*"\([^"]*\)"$/\1/' \
          | "$grep_bin" -E "^''${prefix_re}\.[0-9]+$" \
          | "$sed_bin" "s/^''${prefix_re}\.//" \
          | "$sort_bin" -n \
          | "$tail_bin" -n1 || true)"
        [ -n "$best_patch" ] && resolved="''${prefix}.''${best_patch}"
      fi

      if [ -z "$resolved" ] && [ -d "$cache_dir" ]; then
        resolved="$("$ls_bin" "$cache_dir" 2>/dev/null \
          | "$grep_bin" -E "^''${prefix_re}\.[0-9]+\.jar$" \
          | "$sed_bin" 's/\.jar$//' \
          | "$sort_bin" -t. -k3 -n \
          | "$tail_bin" -n1 || true)"
        [ -n "$resolved" ] && log "GitHub unreachable; using cached ''${resolved}."
      fi

      if [ -z "$resolved" ]; then
        log "Could not resolve a ''${prefix} language server release from GitHub or cache."
        exit 1
      fi

      jar="''${cache_dir}/''${resolved}.jar"

      if [ ! -f "$jar" ]; then
        "$mkdir_bin" -p "$cache_dir"
        url="https://github.com/nextflow-io/language-server/releases/download/''${resolved}/language-server-all.jar"
        "$curl_bin" -fsSL "$url" -o "''${jar}.tmp"
        "$mv_bin" "''${jar}.tmp" "$jar"
        log "downloaded ''${resolved}."
      fi
    fi

    exec "$java_bin" -jar "$jar" "$@"
  '';
  nextflowLspConfig = pkgs.writeText "omp-lsp.json" (
    builtins.toJSON {
      nextflow = {
        command = "${nextflowLanguageServer}/bin/nextflow-language-server";
        extensionToLanguage = {
          ".nf" = "nextflow";
          ".config" = "nextflow-config";
        };
        startupTimeout = 120000;
      };
    }
  );
  ompPackage = pkgs.stdenvNoCC.mkDerivation {
    name = "${cfg.package.pname or "omp"}-isolated";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall

      cp -a ${cfg.package} "$out"
      chmod -R u+w "$out"

      if [ -x "$out/lib/omp/omp" ] && [ -x /usr/bin/codesign ]; then
        /usr/bin/codesign -f -s - "$out/lib/omp/omp"
      fi

      rm -f "$out/bin/omp"
      makeWrapper "$out/lib/omp/omp" "$out/bin/omp" \
        --set PI_SKIP_VERSION_CHECK 1 \
        --set PI_CONFIG_DIR ${lib.escapeShellArg ompConfigDir} \
        --set PI_CODING_AGENT_DIR ${lib.escapeShellArg ompAgentDir} \
        --set PI_PERMISSION_SYSTEM_CONFIG_PATH ${lib.escapeShellArg "${ompAgentDir}/extensions/pi-permission-system/config.json"}${
          lib.optionalString (
            cfg.smolModel != null
          ) " --set PI_SMOL_MODEL ${lib.escapeShellArg cfg.smolModel}"
        }

      runHook postInstall
    '';
    meta = cfg.package.meta or { };
  };
in
{
  options.modules.agents.omp = {
    enable = mkBoolOpt false;
    package = mkOption {
      type = types.package;
      default = pkgs.llm-agents.omp;
      description = "OMP package to install.";
    };
    smolModel = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "xai-oauth/grok-composer-2.5-fast";
      description = ''
        Per-host override for the smol/fast model role, injected as
        PI_SMOL_MODEL. Also drives the commit role, which falls back to smol
        when modelRoles.commit is unset. Null keeps whatever modelRoles.smol is
        set in the mutable ~/.omp/agent/config.yml. default/slow/plan are
        intentionally not exposed here — they live in the mutable config and
        stay identical across hosts.
      '';
    };
  };

  config = mkIf cfg.enable {
    user.packages = [
      (lib.hiPrio ompPackage)
    ];

    home.file.".omp/agent/config.yml" = {
      source = "${configDir}/omp/config.yml";
      force = true;
    };

    home.file.".omp/agent/lsp.json" = {
      source = nextflowLspConfig;
      force = true;
    };

    home.file.".omp/agent/extensions/permission-policy-guard".source =
      "${configDir}/omp/extensions/permission-policy-guard";

    home.file.".omp/agent/extensions/pi-permission-system/config.json".source =
      "${configDir}/pi/pi-permission-system.jsonc";
  };
}
