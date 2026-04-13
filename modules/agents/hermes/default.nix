{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents.hermes;
  inherit (config.dotfiles) configDir;

  hermesSource = inputs.hermesAgent;
  hermesDarwinVenv = pkgs.callPackage (hermesSource + /nix/python.nix) {
    inherit (hermesSource.inputs) uv2nix pyproject-nix pyproject-build-systems;
    # Hermes 0.9.0's Darwin env fails on Python 3.11 via sphinx 9.1.
    python311 = pkgs.python312;
  };
  hermesBundledSkills = lib.cleanSourceWith {
    src = hermesSource + /skills;
    filter = path: _type: !(lib.hasInfix "/index-cache/" path);
  };
  hermesRuntimePath = lib.makeBinPath (
    with pkgs;
    [
      nodejs_20
      ripgrep
      git
      openssh
      ffmpeg
      tirith
    ]
  );
  hermesDarwinPackage = pkgs.stdenv.mkDerivation {
    pname = "hermes-agent";
    inherit ((builtins.fromTOML (builtins.readFile (hermesSource + /pyproject.toml))).project) version;

    dontUnpack = true;
    dontBuild = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/hermes-agent $out/bin
      cp -r ${hermesBundledSkills} $out/share/hermes-agent/skills

      ${lib.concatMapStringsSep "\n"
        (name: ''
          makeWrapper ${hermesDarwinVenv}/bin/${name} $out/bin/${name} \
            --suffix PATH : "${hermesRuntimePath}" \
            --set HERMES_BUNDLED_SKILLS $out/share/hermes-agent/skills
        '')
        [
          "hermes"
          "hermes-agent"
          "hermes-acp"
        ]
      }

      runHook postInstall
    '';

    meta = with lib; {
      description = "AI agent with advanced tool-calling capabilities";
      homepage = "https://github.com/NousResearch/hermes-agent";
      mainProgram = "hermes";
      license = licenses.mit;
      platforms = platforms.unix;
    };
  };
  hermesBasePackage =
    if pkgs.stdenv.hostPlatform.system == "aarch64-darwin" then
      hermesDarwinPackage
    else
      inputs.hermesAgent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  acpxPackage = pkgs.buildNpmPackage rec {
    pname = "acpx";
    version = "0.5.3";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/acpx/-/acpx-0.5.3.tgz";
      hash = "sha512-LNKc9gWlRztWKtQ3jr4g/kzlL9HU/5Wor79mromg/zRV5vE2FOdU+8VtW8ZypIMLzxLx2ATN6A4S1Dr97DM2QQ==";
    };

    sourceRoot = "package";
    postPatch = ''
      cp ${./acpx-package.json} package.json
      cp ${./acpx-package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-NRqF7ELRjP6bwXqs9yAg5b0bOazexc6tUTACQaNlpEc=";
    npmDepsFetcherVersion = 2;
    dontNpmBuild = true;

    meta = {
      description = "Headless CLI client for the Agent Client Protocol";
      homepage = "https://github.com/openclaw/acpx";
      license = lib.licenses.mit;
      mainProgram = "acpx";
    };
  };
  hermesPackageWithAcp = pkgs.stdenvNoCC.mkDerivation {
    pname = hermesBasePackage.pname or "hermes-agent";
    version = "${hermesBasePackage.version or "wrapped"}-with-acp";
    dontUnpack = true;
    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.python3
      pkgs.nodejs
    ];
    installPhase = ''
      runHook preInstall

      cp -a ${hermesBasePackage} "$out"
      chmod -R u+w "$out"

      mkdir -p "$out/bin"
      ln -sf ${acpxPackage}/bin/acpx "$out/bin/acpx"
      if [ -x "$out/bin/hermes" ]; then
        wrapProgram "$out/bin/hermes" \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs.nodejs
              acpxPackage
            ]
          }
      fi

      runHook postInstall
    '';
    inherit (hermesBasePackage) meta;
  };

  yamlFormat = pkgs.formats.yaml { };
  yamlPython = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  hermesVcc = pkgs.callPackage ../../../packages/hermes-vcc/default.nix { };
  secretRefsJson = pkgs.writeText "hermes-secret-references.json" (
    builtins.toJSON cfg.secretReferences
  );
  opBin =
    let
      resolved = builtins.tryEval (lib.getExe pkgs._1password-cli);
    in
    if resolved.success then resolved.value else "op";

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
      default = "$XDG_CONFIG_HOME/hermes";
      description = "Hermes home directory exported as HERMES_HOME.";
    };

    package = mkOption {
      type = package;
      default = hermesPackageWithAcp;
      description = ''
        Hermes package to install. The default wraps the upstream Hermes build
        with the Agent Client Protocol Python dependency so `hermes acp`
        works out of the box on laptop installs.
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
  };

  config = mkIf cfg.enable {
    user.packages = [ cfg.package ];
    env.HERMES_HOME = cfg.homeDir;

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.sessionVariables.HERMES_HOME = cfg.homeDir;

        home.activation.hermes-bootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                    configured_home=${escapeShellArg cfg.homeDir}
                    hermes_home="$(${pkgs.python3}/bin/python3 - "$configured_home" <<'PY'
          import os
          import sys

          os.environ.setdefault("XDG_CONFIG_HOME", os.path.join(os.path.expanduser("~"), ".config"))
          print(os.path.expanduser(os.path.expandvars(sys.argv[1])))
          PY
                    )"
                    legacy_home="$HOME/.hermes"
                    config_target="$hermes_home/config.yaml"
                    soul_target="$hermes_home/SOUL.md"
                    skins_target="$hermes_home/skins"

                    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$hermes_home")"

                    if [ ! -e "$hermes_home" ] && [ -d "$legacy_home" ] && [ "$legacy_home" != "$hermes_home" ]; then
                      echo "Migrating Hermes home from $legacy_home to $hermes_home"
                      ${pkgs.coreutils}/bin/mv "$legacy_home" "$hermes_home"
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
                        ${yamlPython}/bin/python3 - "$tmp" ${escapeShellArg secretRefsJson} "$dotenv_target" ${escapeShellArg opBin} <<'PY'
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

          kept_lines = []
          for line in existing_lines:
              key, sep, _rest = line.partition("=")
              if sep and key in managed_keys:
                  continue
              kept_lines.append(line)

          rendered_lines = list(kept_lines)
          for key, ref in refs.items():
              try:
                  value = subprocess.check_output(
                      [op_bin, "read", ref],
                      text=True,
                      stderr=subprocess.DEVNULL,
                      timeout=15,
                  ).rstrip("\n")
              except Exception:
                  print(
                      f"warning: failed to read Hermes secret {key} from 1Password reference {ref}",
                      file=sys.stderr,
                  )
                  continue

              if not value:
                  print(
                      f"warning: Hermes secret {key} resolved empty from 1Password reference {ref}",
                      file=sys.stderr,
                  )
                  continue

              rendered_lines.append(f"{key}={value}")

          content = "\n".join(rendered_lines)
          if content:
              content += "\n"

          target.write_text(content, encoding="utf-8")
          os.chmod(target, 0o600)
          PY
                        ${pkgs.coreutils}/bin/install -m 0600 "$tmp" "$dotenv_target"
                        ${pkgs.coreutils}/bin/rm -f "$tmp"
                      else
                        echo "warning: 1Password CLI unavailable; skipping Hermes dotenv materialization" >&2
                      fi
                    fi
        '';
      };
  };
}
