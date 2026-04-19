{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents.hermes;
  inherit (config.dotfiles) configDir;

  hermesPackageWithAcp = pkgs.my."hermes-agent-with-acp";

  yamlFormat = pkgs.formats.yaml { };
  yamlPython = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  hermesVcc = pkgs.my.hermes-vcc;
  secretRefsJson = pkgs.writeText "hermes-secret-references.json" (
    builtins.toJSON cfg.secretReferences
  );
  hermesRequiredSecretKeys = lib.unique (
    cfg.requiredSecretKeys ++ lib.optionals cfg.honcho.enable [ "HONCHO_API_KEY" ]
  );
  hermesRequiredSecretKeysEnv = lib.concatStringsSep "," hermesRequiredSecretKeys;
  hermesRequiredSecretKeysJson = pkgs.writeText "hermes-required-secret-keys.json" (
    builtins.toJSON hermesRequiredSecretKeys
  );
  opBin =
    let
      resolved = builtins.tryEval (lib.getExe pkgs._1password-cli);
    in
    if resolved.success then resolved.value else "op";
  opReadTimeoutSeconds = 15;
  hermesSecretPreflight = pkgs.writeShellScript "hermes-secret-preflight" ''
    set -euo pipefail

    configured_home=${escapeShellArg cfg.homeDir}
    hermes_home="$(${pkgs.python3}/bin/python3 - "$configured_home" <<'PY'
    import os
    import sys

    os.environ.setdefault("XDG_CONFIG_HOME", os.path.join(os.path.expanduser("~"), ".config"))
    print(os.path.expanduser(os.path.expandvars(sys.argv[1])))
    PY
    )"
    dotenv_path="$hermes_home/.env"

    ${pkgs.python3}/bin/python3 - ${escapeShellArg hermesRequiredSecretKeysJson} "$dotenv_path" <<'PY'
    import json
    import os
    import pathlib
    import sys


    required = [key for key in json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")) if key]
    if not required:
        raise SystemExit(0)

    dotenv_path = pathlib.Path(sys.argv[2])
    dotenv_values = {}
    if dotenv_path.exists():
        for raw_line in dotenv_path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[7:].lstrip()
            key, sep, value = line.partition("=")
            if not sep:
                continue
            dotenv_values[key] = value

    missing = []
    for key in required:
        value = os.environ.get(key)
        if value is None:
            value = dotenv_values.get(key)
        if value is None or value == "":
            missing.append(key)

    if missing:
        print(
            f"error: Hermes startup blocked; missing required secret env var(s): {', '.join(missing)}",
            file=sys.stderr,
        )
        print(
            f"error: checked process environment and dotenv file: {dotenv_path}",
            file=sys.stderr,
        )
        print(
            "error: unlock 1Password and run `hey re`, or export these env vars before starting Hermes.",
            file=sys.stderr,
        )
        raise SystemExit(42)
    PY
  '';

  renderedSettings =
    optionalAttrs ((config.time.timeZone or "") != "") {
      timezone = config.time.timeZone;
    }
    // cfg.settings;

  renderedConfig = yamlFormat.generate "hermes-settings.yaml" renderedSettings;
  soulFile = "${configDir}/hermes/SOUL.md";
  inherit (cfg) configFile skinsDir;
in
{
  options.modules.agents.hermes = with types; {
    enable = mkBoolOpt false;

    homeDir = mkOption {
      type = str;
      default = "${config.user.home}/.hermes";
      description = "Hermes home directory (defaults to ~/.hermes).";
    };

    package = mkOption {
      type = package;
      default = hermesPackageWithAcp;
      description = ''
        Hermes package to install. The default uses the overlay-managed
        Hermes wrapper package with ACP editor integration assets.
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

    requiredSecretKeys = mkOption {
      type = listOf str;
      default = [ ];
      example = [ "HONCHO_API_KEY" ];
      description = ''
        Additional Hermes secrets that must be present at runtime startup.
        Missing required keys fail Hermes startup in a wrapper preflight, but
        activation/rebuild remains non-fatal.
      '';
    };
  };

  config = mkIf cfg.enable {
    user.packages = [ cfg.package ];
    env.HERMES_HOME = cfg.homeDir;
    env.HERMES_REQUIRED_SECRET_KEYS = hermesRequiredSecretKeysEnv;

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.sessionVariables.HERMES_HOME = cfg.homeDir;
        home.sessionVariables.HERMES_REQUIRED_SECRET_KEYS = hermesRequiredSecretKeysEnv;

        home.activation.hermes-bootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                    hermes_home=${escapeShellArg cfg.homeDir}
                    config_target="$hermes_home/config.yaml"
                    soul_target="$hermes_home/SOUL.md"
                    skins_target="$hermes_home/skins"

                    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$hermes_home")"

                    legacy_xdg_home="${config.user.home}/.config/hermes"
                    if [ ! -e "$hermes_home" ] && [ -d "$legacy_xdg_home" ] && [ "$legacy_xdg_home" != "$hermes_home" ]; then
                      echo "Migrating Hermes home from $legacy_xdg_home to $hermes_home"
                      ${pkgs.coreutils}/bin/mv "$legacy_xdg_home" "$hermes_home"
                    fi

                    ${pkgs.coreutils}/bin/mkdir -p "$hermes_home" "$hermes_home/memories" "$skins_target"

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
