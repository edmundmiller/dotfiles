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
  cfg = config.modules.agents.omp;
  inherit (config.dotfiles) configDir;
  ompConfigDir = "${config.user.home}/.omp";
  ompAgentDir = "${ompConfigDir}/agent";
  lsp = import ./_lsp.nix { inherit pkgs; };
  hassMcpServer = pkgs.writeShellScriptBin "omp-ha-mcp-server" ''
    set -euo pipefail

    token_path=/run/agenix/ha-hermes-token

    if [ -r "$token_path" ]; then
      token=$(${pkgs.coreutils}/bin/cat "$token_path")
    elif [ -e "$token_path" ] && command -v sudo >/dev/null 2>&1; then
      # The NUC grants passwordless sudo for this root-owned agenix token.
      token=$(sudo ${pkgs.coreutils}/bin/cat "$token_path")
    else
      token=$(
        ${pkgs.openssh}/bin/ssh \
          -o BatchMode=yes \
          -o ConnectTimeout=5 \
          nuc \
          "sudo cat /run/agenix/ha-hermes-token"
      )
    fi

    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    umask 077
    config_path="$tmp_dir/mcporter.json"
    token_file="$tmp_dir/ha-token"
    printf '%s' "$token" > "$token_file"
    ${pkgs.jq}/bin/jq -n \
      --rawfile token "$token_file" \
      '{
        mcpServers: {
          hass: {
            type: "http",
            url: "https://homeassistant.cinnamon-rooster.ts.net/api/mcp",
            headers: {
              Authorization: ("Bearer " + ($token | sub("\n$"; "")))
            }
          }
        }
      }' > "$config_path"
    rm -f "$token_file"

    ${pkgs.llm-agents.mcporter}/bin/mcporter \
      --config "$config_path" \
      serve \
      --servers hass \
      --stdio
  '';
  herdrPlugin = pkgs.fetchzip {
    name = "omp-pi-herdr-0.2.5";
    url = "https://registry.npmjs.org/@ogulcancelik/pi-herdr/-/pi-herdr-0.2.5.tgz";
    hash = "sha256-k7Bh17ULoYnlT13u5z3Kvm/iRK7AA0YzJK4ZGNcY+LY=";
  };
  skilloptSleepPlugin = ../../../packages/pi-packages/omp-skillopt-sleep;
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
  threadIntrospectionPrompt = "${config.user.home}/.config/dotfiles/config/omp/prompts/thread-introspection.md";
  threadIntrospection = pkgs.writeShellScriptBin "omp-thread-introspection" ''
    set -euo pipefail

    repo=${lib.escapeShellArg "${config.user.home}/.config/dotfiles"}
    git=${pkgs.git}/bin/git
    commit_enabled=${if cfg.dailyIntrospection.commit.enable then "1" else "0"}
    push_enabled=${if cfg.dailyIntrospection.push.enable then "1" else "0"}

    cd "$repo"

    date_arg="''${1:-}"
    tmp_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
    prompt_file="$tmp_dir/prompt"
    privacy_before="$tmp_dir/privacy-before.json"
    changed_paths="$tmp_dir/changed-paths"
    trap 'rm -rf "$tmp_dir"' EXIT

    if [ "$commit_enabled" = 1 ]; then
      if [ -n "$("$git" status --porcelain --untracked-files=all)" ]; then
        echo "Skipping OMP thread introspection: repository is dirty before run."
        exit 0
      fi

      ${pkgs.python3}/bin/python3 - "$privacy_before" <<'PY'
    from pathlib import Path
    import json
    import re
    import sys

    patterns = {
        "email": re.compile(r"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"),
        "person_name_or_user": re.compile(r"(?i)\b(edmund|emiller|edmundmiller|edmund\.a\.miller)\b"),
        "home_path": re.compile(r"/Users/[^\s`\"']+"),
        "secret_ref": re.compile(r"op://[^\s`\"']+|/run/(agenix|secrets)/[^\s`\"']+"),
        "private_host_or_tailnet": re.compile(r"(?i)\b(MacTraitor-Pro|Seqeratop|cinnamon-rooster|\.ts\.net|\bnuc\b)\b"),
        "memory_artifact": re.compile(r"(?i)\b(mnemopi|coding-agent-transcript|conversation transcript|turn=|profile p[0-9a-f-]{8,}|/chatmem)\b"),
    }
    roots = [Path("skills/catalog"), Path(".agents/skills")]
    counts = {}
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in {".md", ".txt", ".json", ".yml", ".yaml"}:
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            for name, pattern in patterns.items():
                hits = sum(1 for line in text.splitlines() if pattern.search(line))
                if hits:
                    counts[f"{path}|{name}"] = hits
    Path(sys.argv[1]).write_text(json.dumps(counts, sort_keys=True), encoding="utf-8")
    PY
    fi

    ${pkgs.python3}/bin/python3 - "$date_arg" ${lib.escapeShellArg threadIntrospectionPrompt} "$prompt_file" <<'PY'
    from datetime import datetime, timedelta
    from pathlib import Path
    import json
    import sys

    date_arg, template_path, prompt_path = sys.argv[1:4]
    if date_arg:
        day = datetime.strptime(date_arg, "%Y-%m-%d")
    else:
        day = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=1)

    start = day.timestamp()
    end = (day + timedelta(days=1)).timestamp()
    home = Path.home()
    sources = [
        ("omp", "jsonl", home / ".omp" / "agent" / "sessions", ("*.jsonl",)),
        ("codex", "jsonl", home / ".codex" / "sessions", ("*.jsonl",)),
        ("codex-archived", "jsonl", home / ".codex" / "archived_sessions", ("*.jsonl",)),
        ("claude", "jsonl", home / ".claude" / "sessions", ("*.jsonl",)),
        ("claude-projects", "jsonl", home / ".claude" / "projects", ("*.jsonl",)),
        ("pi", "jsonl", home / ".pi" / "agent" / "sessions", ("*.jsonl",)),
        ("opencode", "sqlite", home / ".local" / "share" / "opencode", ("opencode.db",)),
        ("amp", "json", home / ".codex" / "amp-bridge", ("amp-threads.json", "amp-transcripts/*.json")),
        ("amp", "jsonl", home / ".codex" / "amp-bridge", ("amp-transcripts/*.jsonl",)),
        ("droid", "jsonl", home / ".droid" / "sessions", ("*.jsonl",)),
        ("droid", "jsonl", home / ".config" / "droid" / "sessions", ("*.jsonl",)),
    ]

    sessions = []
    for client, file_format, root, patterns in sources:
        if not root.exists():
            continue
        for pattern in patterns:
            for path in root.rglob(pattern):
                if not path.is_file():
                    continue
                stat = path.stat()
                if start <= stat.st_mtime < end:
                    sessions.append({
                        "client": client,
                        "format": file_format,
                        "path": str(path),
                        "bytes": stat.st_size,
                        "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                    })
    sessions.sort(key=lambda item: (item["client"], item["path"]))
    template = Path(template_path).read_text(encoding="utf-8")
    prompt = template.replace("{{DATE}}", day.strftime("%Y-%m-%d"))
    prompt += "\n\n## Session manifest\n\n"
    prompt += json.dumps(sessions, indent=2, sort_keys=True)
    prompt += "\n"
    Path(prompt_path).write_text(prompt, encoding="utf-8")
    PY

    prompt="$(${pkgs.coreutils}/bin/cat "$prompt_file")"
    ${ompPackage}/bin/omp \
      --model ${lib.escapeShellArg cfg.dailyIntrospection.model} \
      --no-session \
      --max-time ${toString cfg.dailyIntrospection.maxTimeSeconds} \
      --tools=read,grep,glob,edit,write \
      --approval-mode yolo \
      -p "$prompt"

    if [ "$commit_enabled" = 1 ]; then
      ${pkgs.python3}/bin/python3 - "$git" "$privacy_before" "$changed_paths" <<'PY'
    from pathlib import Path
    import json
    import re
    import subprocess
    import sys

    git, before_path, changed_path = sys.argv[1:4]
    status = subprocess.check_output(
        [git, "status", "--porcelain", "--untracked-files=all"],
        text=True,
    )

    def parse_path(line: str) -> str:
        path = line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        return path

    paths = [parse_path(line) for line in status.splitlines() if line.strip()]

    def allowed(path: str) -> bool:
        return (
            (path.startswith("config/agents/rules/") and path.endswith(".md"))
            or (path.startswith("config/omp/prompts/") and path.endswith(".md"))
            or path.startswith("skills/catalog/")
            or path.startswith(".agents/skills/")
        )

    blocked = [path for path in paths if not allowed(path)]
    if blocked:
        print("Refusing to auto-commit unexpected paths:")
        for path in blocked:
            print(f"- {path}")
        raise SystemExit(1)

    patterns = {
        "email": re.compile(r"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"),
        "person_name_or_user": re.compile(r"(?i)\b(edmund|emiller|edmundmiller|edmund\.a\.miller)\b"),
        "home_path": re.compile(r"/Users/[^\s`\"']+"),
        "secret_ref": re.compile(r"op://[^\s`\"']+|/run/(agenix|secrets)/[^\s`\"']+"),
        "private_host_or_tailnet": re.compile(r"(?i)\b(MacTraitor-Pro|Seqeratop|cinnamon-rooster|\.ts\.net|\bnuc\b)\b"),
        "memory_artifact": re.compile(r"(?i)\b(mnemopi|coding-agent-transcript|conversation transcript|turn=|profile p[0-9a-f-]{8,}|/chatmem)\b"),
    }
    before = json.loads(Path(before_path).read_text(encoding="utf-8"))
    after = {}
    for path in paths:
        file_path = Path(path)
        if not (path.startswith("skills/catalog/") or path.startswith(".agents/skills/")):
            continue
        if not file_path.exists() or file_path.suffix.lower() not in {".md", ".txt", ".json", ".yml", ".yaml"}:
            continue
        text = file_path.read_text(encoding="utf-8", errors="ignore")
        for name, pattern in patterns.items():
            hits = sum(1 for line in text.splitlines() if pattern.search(line))
            if hits:
                after[f"{path}|{name}"] = hits

    increases = []
    for key, count in after.items():
        if count > before.get(key, 0):
            increases.append((key, before.get(key, 0), count))
    if increases:
        print("Refusing to auto-commit increased privacy findings:")
        for key, old, new in increases:
            path, rule = key.rsplit("|", 1)
            print(f"- {path}: {rule} {old}->{new}")
        raise SystemExit(1)

    Path(changed_path).write_text("\n".join(paths) + ("\n" if paths else ""), encoding="utf-8")
    PY

      if [ ! -s "$changed_paths" ]; then
        echo "OMP thread introspection made no changes."
        exit 0
      fi

      ${pkgs.python3}/bin/python3 - "$git" "$changed_paths" <<'PY'
    from pathlib import Path
    import subprocess
    import sys

    git, changed_path = sys.argv[1:3]
    paths = [line for line in Path(changed_path).read_text(encoding="utf-8").splitlines() if line]
    subprocess.run([git, "add", "--", *paths], check=True)
    PY
      ./bin/hey check
      "$git" commit -m ${lib.escapeShellArg cfg.dailyIntrospection.commit.message}

      if [ "$push_enabled" = 1 ]; then
        "$git" push
      fi
    fi
  '';
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
    dailyIntrospection = {
      enable = mkBoolOpt false;
      model = mkOpt types.str "openai-codex/gpt-5.5:high";
      hour = mkOpt types.int 4;
      minute = mkOpt types.int 30;
      maxTimeSeconds = mkOpt types.int 900;
      commit = {
        enable = mkBoolOpt false;
        message = mkOpt types.str "chore(agents): apply daily introspection notes";
      };
      push.enable = mkBoolOpt false;
    };
  };

  config = mkIf cfg.enable {
    user.packages = [
      (lib.hiPrio ompPackage)
      hassMcpServer
    ]
    ++ lib.optional cfg.dailyIntrospection.enable threadIntrospection;

    home.file.".omp/agent/config.yml" = {
      source = "${configDir}/omp/config.yml";
      force = true;
    };

    home.file.".omp/agent/lsp.json" = {
      source = lsp.configFile;
      force = true;
    };

    home.file.".omp/agent/themes/light-catppuccin-readable.json" = {
      source = "${configDir}/omp/themes/light-catppuccin-readable.json";
      force = true;
    };

    home.file.".omp/agent/extensions/permission-policy-guard".source =
      "${configDir}/omp/extensions/permission-policy-guard";
    home.file.".omp/agent/extensions/pi-permission-system/config.json".source =
      "${configDir}/pi/pi-permission-system.jsonc";

    launchd.user.agents = optionalAttrs (isDarwin && cfg.dailyIntrospection.enable) {
      omp-thread-introspection = {
        command = "${threadIntrospection}/bin/omp-thread-introspection";
        serviceConfig = {
          StartCalendarInterval = {
            Hour = cfg.dailyIntrospection.hour;
            Minute = cfg.dailyIntrospection.minute;
          };
          StandardOutPath = "${config.user.home}/Library/Logs/omp-thread-introspection.log";
          StandardErrorPath = "${config.user.home}/Library/Logs/omp-thread-introspection.err.log";
          EnvironmentVariables = {
            HOME = config.user.home;
          };
        };
      };
    };

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.activation.omp-herdr-plugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${ompPackage}/bin/omp plugin link ${lib.escapeShellArg "${herdrPlugin}"} --force --json >/dev/null
        '';

        home.activation.omp-skillopt-sleep-plugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${ompPackage}/bin/omp plugin uninstall pi-skillopt-sleep --json >/dev/null 2>&1 || true
          ${ompPackage}/bin/omp plugin link ${lib.escapeShellArg "${skilloptSleepPlugin}"} --force --json >/dev/null
        '';

        home.activation.omp-mcp-cleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${pkgs.python3}/bin/python3 <<'PY'
          import pathlib
          import sqlite3

          db_path = pathlib.Path.home() / ".omp" / "agent" / "agent.db"
          if db_path.exists():
              try:
                  conn = sqlite3.connect(db_path)
                  try:
                      conn.execute("delete from cache where key like 'mcp_tools:%'")
                      conn.commit()
                  finally:
                      conn.close()
              except Exception:
                  pass

          PY
        '';
      };
  };
}
