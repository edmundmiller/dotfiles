{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents."hermes-desktop";
  inherit (config.dotfiles) configDir;

  hermesPackage = pkgs.llm-agents."hermes-agent";

  yamlFormat = pkgs.formats.yaml { };
  yamlPython = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  hermesVcc = pkgs.my.hermes-vcc;
  secretRefsJson = pkgs.writeText "hermes-secret-references.json" (
    builtins.toJSON cfg.secretReferences
  );
  opBin =
    let
      resolved = builtins.tryEval (lib.getExe pkgs._1password-cli);
    in
    if resolved.success then resolved.value else "op";
  opReadTimeoutSeconds = 15;

  renderedSettings = lib.recursiveUpdate (
    optionalAttrs ((config.time.timeZone or "") != "") {
      timezone = config.time.timeZone;
    }
    // {
      model.openai_runtime = "codex_app_server";
      kanban.dispatch_in_gateway = true;
    }
  ) cfg.settings;

  renderedConfig = yamlFormat.generate "hermes-settings.yaml" renderedSettings;
  soulFile = "${configDir}/hermes/SOUL.md";
  hermesPluginsDir = "${configDir}/hermes/plugins";
  codexAuthSync = pkgs.writeText "hermes-codex-auth-sync.py" ''
    import base64
    import json
    import pathlib
    import sys
    import time
    from datetime import datetime, timezone


    def read_json(path: pathlib.Path) -> dict:
        try:
            return json.loads(path.read_text(encoding="utf-8")) or {}
        except Exception:
            return {}


    def jwt_exp(token: str) -> int:
        try:
            payload = token.split(".")[1]
            payload += "=" * ((4 - len(payload) % 4) % 4)
            return int(json.loads(base64.urlsafe_b64decode(payload)).get("exp") or 0)
        except Exception:
            return 0


    codex_auth = pathlib.Path(sys.argv[1]).expanduser()
    hermes_auth = pathlib.Path(sys.argv[2]).expanduser()
    if not codex_auth.is_file():
        raise SystemExit(0)

    codex_data = read_json(codex_auth)
    codex_tokens = codex_data.get("tokens")
    if not isinstance(codex_tokens, dict) or not codex_tokens.get("access_token"):
        raise SystemExit(0)

    codex_exp = jwt_exp(codex_tokens.get("access_token", ""))
    # Prefer currently usable Codex CLI access tokens, but still import an
    # expired access token when the shared login has a refresh token. Hermes can
    # refresh that OAuth credential; skipping it here can leave an older Hermes
    # auth.json with no access_token at all.
    if codex_exp and codex_exp <= int(time.time()) + 60 and not codex_tokens.get("refresh_token"):
        raise SystemExit(0)

    data = read_json(hermes_auth)
    hermes_tokens = (
        data.get("providers", {})
        .get("openai-codex", {})
        .get("tokens", {})
    )
    hermes_exp = jwt_exp(hermes_tokens.get("access_token", "")) if isinstance(hermes_tokens, dict) else 0
    if hermes_exp and hermes_exp >= codex_exp:
        raise SystemExit(0)

    now = datetime.now(timezone.utc).isoformat()
    if not isinstance(data, dict) or "providers" not in data:
        data = {"version": 1, "providers": {}}

    provider_payload = {
        "tokens": codex_tokens,
        "last_refresh": codex_data.get("last_refresh") or now,
        "auth_mode": codex_data.get("auth_mode") or "chatgpt",
    }
    data.setdefault("version", 1)
    data.setdefault("providers", {})["openai-codex"] = provider_payload
    data["active_provider"] = "openai-codex"
    data["updated_at"] = now

    pool_entry = {
        "auth_type": "oauth",
        "source": "device_code",
        "label": "Codex CLI shared login",
        "access_token": codex_tokens.get("access_token"),
        "refresh_token": codex_tokens.get("refresh_token"),
        "id_token": codex_tokens.get("id_token"),
        "account_id": codex_tokens.get("account_id"),
        "last_refresh": provider_payload["last_refresh"],
    }
    pool_entry = {key: value for key, value in pool_entry.items() if value}
    pool = data.setdefault("credential_pool", {})
    existing = pool.setdefault("openai-codex", [])
    pool["openai-codex"] = [
        pool_entry,
        *[
            entry
            for entry in existing
            if not (
                isinstance(entry, dict)
                and entry.get("source") in {"device_code", "manual:device_code"}
            )
        ],
    ]

    hermes_auth.parent.mkdir(parents=True, exist_ok=True)
    tmp = hermes_auth.with_suffix(hermes_auth.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    tmp.replace(hermes_auth)
    hermes_auth.chmod(0o600)
    print(f"Synced Hermes OpenAI Codex auth from {codex_auth}", file=sys.stderr)
  '';
  inherit (cfg) configFile skinsDir hooksDir;
in
{
  options.modules.agents."hermes-desktop" = with types; {
    enable = mkBoolOpt false;

    homeDir = mkOption {
      type = str;
      default = "${config.user.home}/.hermes";
      description = "Hermes home directory (defaults to ~/.hermes).";
    };

    package = mkOption {
      type = package;
      default = hermesPackage;
      description = ''
        Hermes package to install. The default uses llm-agents.nix's
        hermes-agent package directly.
      '';
    };

    configFile = mkOption {
      type = str;
      default = "${configDir}/hermes/config.yml";
      description = "Editable Hermes base config merged into $HERMES_HOME/config.yaml.";
    };

    skinsDir = mkOption {
      type = str;
      default = "${configDir}/hermes/skins";
      description = ''
        Repo-managed Hermes skins materialized into $HERMES_HOME/skins.
        User-created skins outside this directory are preserved.
      '';
    };

    hooksDir = mkOption {
      type = str;
      default = "${configDir}/hermes/hooks";
      description = ''
        Repo-managed Hermes hooks materialized into $HERMES_HOME/hooks.
        Nested directory structure is preserved. .py files get mode 0755.
      '';
    };

    settings = mkOption {
      type = attrsOf anything;
      default = { };
      description = ''
        Declarative Hermes overlays merged on top of configFile and existing
        user config during activation. Nix-managed keys win over the base file,
        but user-added keys outside these overlays are preserved.
      '';
    };

    honcho = {
      enable = mkBoolOpt false;

      configFile = mkOption {
        type = str;
        default = "${configDir}/hermes/honcho.json";
        description = ''
          Repo-managed Honcho config seeded into $HERMES_HOME/honcho.json on
          first activation. Not overwritten if the file already exists so
          Hermes can mutate it at runtime.
        '';
      };
    };

    secretReferences = mkOption {
      type = attrsOf str;
      default = {
        FIREWORKS_API_KEY = "op://Agents/Fireworks AI Firepass Scintillate Hermes/credential";
        HONCHO_API_KEY = "op://Agents/MTP Honcho/credential";
        KILOCODE_API_KEY = "op://Agents/Kilocode/credential";
        OPENROUTER_API_KEY = "op://Agents/OpenRouter OpenClaw key/credential";
      };
      description = ''
        1Password secret references to materialize into $HERMES_HOME/.env.
        This keeps repo config declarative while avoiding plaintext API keys
        in git. Existing unmanaged .env entries are preserved.
      '';
    };

  };

  config = mkIf cfg.enable {
    user.packages = [
      cfg.package
      pkgs.my.codegraph
    ];
    env.HERMES_HOME = cfg.homeDir;
    # env.HERMES_TUI = "1";

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.sessionVariables.HERMES_HOME = cfg.homeDir;
        # home.sessionVariables.HERMES_TUI = "1";

        home.activation.hermes-bootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                    hermes_home=${escapeShellArg cfg.homeDir}
                    config_target="$hermes_home/config.yaml"
                    soul_target="$hermes_home/SOUL.md"
                    skins_target="$hermes_home/skins"
                    plugins_target="$hermes_home/plugins"
                    hooks_target="$hermes_home/hooks"

                    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$hermes_home")"

                    legacy_xdg_home="${config.user.home}/.config/hermes"
                    if [ ! -e "$hermes_home" ] && [ -d "$legacy_xdg_home" ] && [ "$legacy_xdg_home" != "$hermes_home" ]; then
                      echo "Migrating Hermes home from $legacy_xdg_home to $hermes_home"
                      ${pkgs.coreutils}/bin/mv "$legacy_xdg_home" "$hermes_home"
                    fi

                    ${pkgs.coreutils}/bin/mkdir -p "$hermes_home" "$hermes_home/memories" "$skins_target" "$plugins_target" "$hooks_target"

                    # If a previous version left behind a symlinked config, replace it with
                    # a writable local copy before merging declarative defaults.
                    if [ -L "$config_target" ]; then
                      tmp="$(${pkgs.coreutils}/bin/mktemp)"
                      ${pkgs.coreutils}/bin/cp "$config_target" "$tmp" 2>/dev/null || true
                      ${pkgs.coreutils}/bin/rm -f "$config_target"
                      if [ -s "$tmp" ]; then
                        ${pkgs.coreutils}/bin/mv "$tmp" "$config_target"
                      else
                        ${pkgs.coreutils}/bin/rm -f "$tmp"
                      fi
                    fi

                    ${pkgs.coreutils}/bin/install -Dm644 ${soulFile} "$soul_target"

                    ${lib.optionalString cfg.honcho.enable ''
                      honcho_target="$hermes_home/honcho.json"
                      if [ ! -e "$honcho_target" ]; then
                        ${pkgs.coreutils}/bin/install -Dm600 ${escapeShellArg cfg.honcho.configFile} "$honcho_target"
                      fi
                    ''}

                    skins_source=${escapeShellArg skinsDir}
                    ${pkgs.python3}/bin/python3 - "$skins_source" "$skins_target" <<'PY'
          import pathlib
          import shutil
          import sys


          source = pathlib.Path(sys.argv[1])
          target_root = pathlib.Path(sys.argv[2])


          if source.is_dir():
              for skin_file in source.rglob("*"):
                  if not skin_file.is_file():
                      continue
                  if skin_file.suffix.lower() not in {".yaml", ".yml"}:
                      continue

                  rel_path = skin_file.relative_to(source)
                  dest_path = target_root / rel_path
                  dest_path.parent.mkdir(parents=True, exist_ok=True)
                  if dest_path.exists():
                      dest_path.chmod(0o644)
                  shutil.copy2(skin_file, dest_path)
          PY

                    plugins_source=${escapeShellArg hermesPluginsDir}
                    ${pkgs.python3}/bin/python3 - "$plugins_source" "$plugins_target" <<'PY'
          import pathlib
          import shutil
          import sys


          source = pathlib.Path(sys.argv[1])
          target_root = pathlib.Path(sys.argv[2])


          if source.is_dir():
              for plugin_dir in source.iterdir():
                  if not plugin_dir.is_dir():
                      continue
                  if not (plugin_dir / "plugin.yaml").exists() and not (plugin_dir / "plugin.yml").exists():
                      continue

                  dest_plugin_dir = target_root / plugin_dir.name
                  for path in plugin_dir.rglob("*"):
                      rel_path = path.relative_to(plugin_dir)
                      dest_path = dest_plugin_dir / rel_path
                      if path.is_dir():
                          dest_path.mkdir(parents=True, exist_ok=True)
                          continue

                      dest_path.parent.mkdir(parents=True, exist_ok=True)
                      if dest_path.exists():
                          dest_path.chmod(0o644)
                      shutil.copy2(path, dest_path)
          PY

                    hooks_source=${escapeShellArg hooksDir}
                    ${pkgs.python3}/bin/python3 - "$hooks_source" "$hooks_target" <<'PY'
          import os
          import pathlib
          import shutil
          import sys


          source = pathlib.Path(sys.argv[1])
          target_root = pathlib.Path(sys.argv[2])


          if source.is_dir():
              for hook_file in source.rglob("*"):
                  if not hook_file.is_file():
                      continue

                  rel_path = hook_file.relative_to(source)
                  dest_path = target_root / rel_path
                  dest_path.parent.mkdir(parents=True, exist_ok=True)
                  if dest_path.exists():
                      dest_path.chmod(0o644)
                  shutil.copy2(hook_file, dest_path)
                  mode = 0o755 if hook_file.suffix.lower() == ".py" else 0o644
                  os.chmod(dest_path, mode)
          PY

                    # Install VCC memory plugin into Hermes plugin discovery path
                    plugin_dir="$hermes_home/plugins/memory/vcc"
                    ${pkgs.coreutils}/bin/mkdir -p "$plugin_dir"
                    ${pkgs.coreutils}/bin/install -m 0644 ${hermesVcc}/share/hermes-vcc/plugins/memory/vcc/__init__.py "$plugin_dir/__init__.py"
                    ${pkgs.coreutils}/bin/install -m 0644 ${hermesVcc}/share/hermes-vcc/plugins/memory/vcc/plugin.yaml "$plugin_dir/plugin.yaml"

                    ${yamlPython}/bin/python3 - "$config_target" ${escapeShellArg configFile} ${renderedConfig} <<'PY'
          import copy
          import pathlib
          import sys

          import yaml


          target = pathlib.Path(sys.argv[1])
          base = pathlib.Path(sys.argv[2])
          overlay = pathlib.Path(sys.argv[3])


          def load_yaml(path: pathlib.Path) -> dict:
              if not path.exists():
                  return {}

              try:
                  data = yaml.safe_load(path.read_text(encoding="utf-8"))
              except Exception as exc:
                  print(
                      f"warning: failed to parse Hermes config {path}: {exc}",
                      file=sys.stderr,
                  )
                  return {}

              return data or {}


          def merge(existing, declarative):
              if isinstance(existing, dict) and isinstance(declarative, dict):
                  merged = {key: copy.deepcopy(value) for key, value in existing.items()}
                  for key, value in declarative.items():
                      if key in merged:
                          merged[key] = merge(merged[key], value)
                      else:
                          merged[key] = copy.deepcopy(value)
                  return merged

              return copy.deepcopy(declarative)


          base_config = load_yaml(base)
          overlay_config = load_yaml(overlay)
          existing_config = load_yaml(target)
          declarative_config = merge(base_config, overlay_config)
          merged_config = merge(existing_config, declarative_config)

          target.write_text(
              yaml.safe_dump(merged_config, sort_keys=False, allow_unicode=True),
              encoding="utf-8",
          )
          PY

                    ${pkgs.python3}/bin/python3 ${codexAuthSync} "${config.user.home}/.codex/auth.json" "$hermes_home/auth.json" || true

                    dotenv_target="$hermes_home/.env"
                    if [ -s ${escapeShellArg secretRefsJson} ]; then
                      if command -v ${escapeShellArg opBin} >/dev/null 2>&1; then
                        tmp="$(${pkgs.coreutils}/bin/mktemp)"
                        # Probe for 1Password availability before attempting secret reads.
                        # If locked/closed, op vault list hangs waiting for Touch ID. Skipping
                        # silently preserves existing secrets without spamming warnings on every
                        # rebuild when 1Password happens to be locked.
                        if ! ${pkgs.coreutils}/bin/timeout 5 ${opBin} vault list >/dev/null 2>&1; then
                          echo "warning: 1Password unavailable (locked or closed); preserving existing Hermes secrets" >&2
                        else
                        ${pkgs.python3}/bin/python3 - "$tmp" ${escapeShellArg secretRefsJson} "$dotenv_target" ${escapeShellArg opBin} <<'PY'
          import json
          import os
          import pathlib
          import subprocess
          import sys


          target = pathlib.Path(sys.argv[1])
          refs_path = pathlib.Path(sys.argv[2])
          dotenv_path = pathlib.Path(sys.argv[3])
          op_bin = sys.argv[4]

          refs = json.loads(refs_path.read_text(encoding="utf-8"))
          managed_keys = set(refs)
          existing_lines = []
          if dotenv_path.exists():
              existing_lines = dotenv_path.read_text(encoding="utf-8").splitlines()

          existing_values = {}
          kept_lines = []
          for line in existing_lines:
              key, sep, rest = line.partition("=")
              if sep:
                  existing_values[key] = rest
              if sep and key in managed_keys:
                  continue
              kept_lines.append(line)

          rendered_lines = list(kept_lines)
          failed_keys = []
          empty_keys = []
          preserved_keys = []
          for key, ref in refs.items():
              try:
                  value = subprocess.check_output(
                      [op_bin, "read", ref],
                      text=True,
                      stderr=subprocess.DEVNULL,
                      timeout=${toString opReadTimeoutSeconds},
                  ).rstrip("\n")
              except Exception:
                  fallback = existing_values.get(key, "")
                  if fallback:
                      preserved_keys.append(f"{key} ({ref})")
                      rendered_lines.append(f"{key}={fallback}")
                      continue
                  failed_keys.append(f"{key} ({ref})")
                  continue

              if not value:
                  fallback = existing_values.get(key, "")
                  if fallback:
                      preserved_keys.append(f"{key} ({ref})")
                      rendered_lines.append(f"{key}={fallback}")
                      continue
                  empty_keys.append(f"{key} ({ref})")
                  continue

              rendered_lines.append(f"{key}={value}")

          if failed_keys:
              sample = ", ".join(failed_keys[:5])
              extra = "" if len(failed_keys) <= 5 else f" (+{len(failed_keys) - 5} more)"
              print(
                  f"warning: failed to read {len(failed_keys)} Hermes secret(s) from 1Password: {sample}{extra}",
                  file=sys.stderr,
              )

          if empty_keys:
              sample = ", ".join(empty_keys[:5])
              extra = "" if len(empty_keys) <= 5 else f" (+{len(empty_keys) - 5} more)"
              print(
                  f"warning: {len(empty_keys)} Hermes secret(s) resolved empty from 1Password: {sample}{extra}",
                  file=sys.stderr,
              )

          if preserved_keys:
              sample = ", ".join(preserved_keys[:5])
              extra = "" if len(preserved_keys) <= 5 else f" (+{len(preserved_keys) - 5} more)"
              print(
                  f"warning: preserving {len(preserved_keys)} existing Hermes secret(s) because 1Password did not return a fresh value: {sample}{extra}",
                  file=sys.stderr,
              )

          content = "\n".join(rendered_lines)
          if content:
              content += "\n"

          target.write_text(content, encoding="utf-8")
          os.chmod(target, 0o600)
          PY
                        ${pkgs.coreutils}/bin/install -m 0600 "$tmp" "$dotenv_target"
                        ${pkgs.coreutils}/bin/rm -f "$tmp"
                        fi
                      else
                        echo "warning: 1Password CLI unavailable; skipping Hermes dotenv materialization" >&2
                      fi
                    fi
        '';
      };
  };
}
