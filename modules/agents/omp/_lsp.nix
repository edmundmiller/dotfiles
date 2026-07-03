{ pkgs }:
let
  launcher = pkgs.writeShellScriptBin "nextflow-language-server" ''
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
in
{
  inherit launcher;

  configFile = pkgs.writeText "omp-lsp.json" (
    builtins.toJSON {
      nextflow = {
        command = "${launcher}/bin/nextflow-language-server";
        extensionToLanguage = {
          ".nf" = "nextflow";
          ".config" = "nextflow-config";
        };
        startupTimeout = 120000;
      };
    }
  );
}
