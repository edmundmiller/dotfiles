{
  lib,
  pkgs,
  piSecretPreflightScript,
}:
let
  nodeGypPython = pkgs.python311.withPackages (ps: [ ps.setuptools ]);
  runtimePath = lib.makeBinPath [
    pkgs.nodejs
    nodeGypPython
  ];
  updateExtensionsShim = lib.concatStringsSep "\n" [
    ''if [ "$#" -eq 1 ] && [ "''${1:-}" = "update" ]; then''
    "  set -- update --extensions"
    "fi"
    ''exec -a "$0" ''
  ];
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

    if [ -x "$out/bin/pi" ]; then
      wrapProgram "$out/bin/pi" \
        --run ${lib.escapeShellArg "${piSecretPreflightScript}"} \
        --prefix PATH : ${lib.escapeShellArg runtimePath} \
        --set AGENT "1" \
        --set PI_CODING_AGENT "true" \
        --set DEVELOPER_DIR "/Library/Developer/CommandLineTools" \
        --set PYTHON ${lib.escapeShellArg "${nodeGypPython}/bin/python3"} \
        --unset SDKROOT

      # The pi executable is Nix-managed and cannot self-update in-place.
      # Make the common `pi update` shortcut update only user packages/extensions;
      # explicit self-update requests like `pi update pi` still pass through and fail loudly.
      substituteInPlace "$out/bin/pi" \
        --replace-fail 'exec -a "$0" ' ${lib.escapeShellArg updateExtensionsShim}
    fi

    runHook postInstall
  '';

  inherit (pkgs.llm-agents.pi) meta;
}
