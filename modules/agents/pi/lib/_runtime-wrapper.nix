{
  lib,
  pkgs,
  piSecretPreflightScript,
}:
let
  piRuntimeNode = pkgs.nodejs_24 or pkgs.nodejs;
  nodeGypPython = pkgs.python311.withPackages (ps: [ ps.setuptools ]);
  runtimePath = lib.makeBinPath [
    piRuntimeNode
    nodeGypPython
  ];
  # Pi splits PI_SELF_UPDATE_COMMAND on whitespace rather than evaluating a
  # shell string. Resolve the checkout here so spaces and overrides stay intact.
  selfUpdate = pkgs.writeShellScript "pi-self-update" ''
    set -euo pipefail
    # GUI/service launches may lack the task interpreter and system tools.
    # Keep caller overrides first; only this updater needs these fallbacks.
    export PATH="''${PATH:+$PATH:}${
      lib.makeBinPath [
        pkgs.nushell
        pkgs.mise
      ]
    }:/run/current-system/sw/bin"
    exec ${lib.getExe pkgs.mise} --cd "''${FLAKE_DIR:-''${DOTFILES:-$HOME/.config/dotfiles}}" run pi:update "$@"
  '';
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "${pkgs.llm-agents.pi.pname or "pi"}-with-runtime-wrapper";
  version = pkgs.llm-agents.pi.version or "wrapped";
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    cp -a ${pkgs.llm-agents.pi} "$out"
    chmod -R u+w "$out"

    ${lib.optionalString pkgs.stdenv.isDarwin ''
      if [ -x "$out/libexec/pi/pi" ]; then
        /usr/bin/codesign -f -s - "$out/libexec/pi/pi"
      fi
    ''}

    if [ -x "$out/bin/pi" ]; then
      substituteInPlace "$out/bin/pi" \
        --replace-fail "${pkgs.llm-agents.pi}/libexec/pi/pi" "$out/libexec/pi/pi"

      wrapProgram "$out/bin/pi" \
        --run ${lib.escapeShellArg "${piSecretPreflightScript}"} \
        --prefix PATH : ${lib.escapeShellArg runtimePath} \
        --set-default NODE_EXTRA_CA_CERTS "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" \
        --set AGENT "1" \
        --set PI_CODING_AGENT "true" \
        --set-default PI_SELF_UPDATE_COMMAND "${selfUpdate} {version}" \
        --set DEVELOPER_DIR "/Library/Developer/CommandLineTools" \
        --set PYTHON ${lib.escapeShellArg "${nodeGypPython}/bin/python3"} \
        --unset SDKROOT
    fi

    runHook postInstall
  '';

  inherit (pkgs.llm-agents.pi) meta;
}
