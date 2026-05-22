{
  lib,
  inputs,
  callPackage,
  stdenv,
  stdenvNoCC,
  makeWrapper,
  writeShellScript,
  python3,
  nodejs,
  nodejs_20,
  ripgrep,
  git,
  openssh,
  ffmpeg,
  tirith,
}:
let
  hermesSource = inputs.hermesAgent;
  hermesDarwinVenv = callPackage (hermesSource + /nix/python.nix) {
    inherit (hermesSource.inputs) uv2nix pyproject-nix pyproject-build-systems;
  };
  hermesBundledSkills = lib.cleanSourceWith {
    src = hermesSource + /skills;
    filter = path: _type: !(lib.hasInfix "/index-cache/" path);
  };
  hermesRuntimePath = lib.makeBinPath [
    nodejs_20
    ripgrep
    git
    openssh
    ffmpeg
    tirith
  ];
  hermesBins = [
    "hermes"
    "hermes-agent"
    "hermes-acp"
  ];
  hermesHomeBootstrapCmd = ''
    export HERMES_HOME="''${HERMES_HOME:-$HOME/.hermes}"
  '';
  hermesSecretPreflight = writeShellScript "hermes-secret-preflight" ''
    set -euo pipefail

    dotenv_path="$HERMES_HOME/.env"
    required_keys="''${HERMES_REQUIRED_SECRET_KEYS:-}"
    if [ -z "$required_keys" ]; then
      exit 0
    fi

    ${python3}/bin/python3 - "$required_keys" "$dotenv_path" <<'PY'
    import os
    import pathlib
    import re
    import sys


    required = [
        key
        for key in re.split(r"[,\s]+", sys.argv[1].strip())
        if key
    ]
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

  hermesDarwinPackage = stdenv.mkDerivation {
    pname = "hermes-agent";
    inherit ((builtins.fromTOML (builtins.readFile (hermesSource + /pyproject.toml))).project) version;

    dontUnpack = true;
    dontBuild = true;
    nativeBuildInputs = [ makeWrapper ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/hermes-agent $out/bin
      cp -r ${hermesBundledSkills} $out/share/hermes-agent/skills

      ${lib.concatMapStringsSep "\n" (name: ''
        makeWrapper ${hermesDarwinVenv}/bin/${name} $out/bin/${name} \
          --suffix PATH : "${hermesRuntimePath}" \
          --set HERMES_BUNDLED_SKILLS $out/share/hermes-agent/skills
      '') hermesBins}

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
    if stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64 then
      hermesDarwinPackage
    else
      inputs.hermesAgent.packages.${stdenv.hostPlatform.system}.default;
in
stdenvNoCC.mkDerivation {
  pname = hermesBasePackage.pname or "hermes-agent";
  version = "${hermesBasePackage.version or "wrapped"}-with-acp";
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    cp -a ${hermesBasePackage} "$out"
    chmod u+w "$out"
    if [ -d "$out/bin" ]; then
      chmod -R u+w "$out/bin"
    fi
    if [ -d "$out/share" ]; then
      chmod -R u+w "$out/share"
    fi

    mkdir -p "$out/share/hermes-agent"
    cp -rT ${hermesSource}/acp_registry "$out/share/hermes-agent/acp_registry"
    rm -rf "$out/acp_registry"
    ln -s "$out/share/hermes-agent/acp_registry" "$out/acp_registry"

    for hermes_bin in ${lib.concatStringsSep " " hermesBins}; do
      if [ -x "$out/bin/$hermes_bin" ]; then
        if [ "$hermes_bin" = "hermes-acp" ]; then
          wrapProgram "$out/bin/$hermes_bin" \
            --prefix PATH : ${lib.makeBinPath [ nodejs ]} \
            --run ${lib.escapeShellArg hermesHomeBootstrapCmd}
        else
          wrapProgram "$out/bin/$hermes_bin" \
            --prefix PATH : ${lib.makeBinPath [ nodejs ]} \
            --run ${lib.escapeShellArg hermesHomeBootstrapCmd} \
            --run ${lib.escapeShellArg "${hermesSecretPreflight}"}
        fi
      fi
    done

    runHook postInstall
  '';

  inherit (hermesBasePackage) meta;
}
