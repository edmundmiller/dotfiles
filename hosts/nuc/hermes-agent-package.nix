{
  inputs,
  lib,
  pkgs,
}:
let
  upstreamHermesAgent = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  fixedHermesNpmDeps = pkgs.fetchNpmDeps {
    src = inputs.hermes-agent;
    fetcherVersion = 2;
    hash = "sha256-rcZA9b/e02qQOvurztSkpQWrGyS2QL8pn0Jc8wuGs2c=";
  };
  fixedHermesWeb = upstreamHermesAgent.passthru.hermesWeb.overrideAttrs (_old: {
    npmDeps = fixedHermesNpmDeps;
  });
  fixedHermesTui = upstreamHermesAgent.passthru.hermesTui.overrideAttrs (_old: {
    npmDeps = fixedHermesNpmDeps;
  });
  hermesVenv = upstreamHermesAgent.passthru.hermesVenv;
  hermesRuntimePath = lib.makeBinPath (
    with pkgs;
    [
      nodejs_22
      ripgrep
      git
      openssh
      ffmpeg
      tirith
      wl-clipboard
      xclip
    ]
  );
in
upstreamHermesAgent.overrideAttrs (_old: {
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/hermes-agent $out/bin
    cp -r ${inputs.hermes-agent}/skills $out/share/hermes-agent/skills
    cp -r ${inputs.hermes-agent}/plugins $out/share/hermes-agent/plugins
    cp -r ${inputs.hermes-agent}/locales $out/share/hermes-agent/locales
    cp -r ${fixedHermesWeb} $out/share/hermes-agent/web_dist

    mkdir -p $out/ui-tui
    cp -r ${fixedHermesTui}/lib/hermes-tui/* $out/ui-tui/

    for exe in hermes hermes-agent hermes-acp; do
      makeWrapper ${hermesVenv}/bin/$exe $out/bin/$exe \
        --suffix PATH : "${hermesRuntimePath}" \
        --set HERMES_BUNDLED_SKILLS $out/share/hermes-agent/skills \
        --set HERMES_BUNDLED_PLUGINS $out/share/hermes-agent/plugins \
        --set HERMES_BUNDLED_LOCALES $out/share/hermes-agent/locales \
        --set HERMES_WEB_DIST $out/share/hermes-agent/web_dist \
        --set HERMES_TUI_DIR $out/ui-tui \
        --set HERMES_PYTHON ${hermesVenv}/bin/python3 \
        --set HERMES_NODE ${lib.getExe pkgs.nodejs_22} \
        --set HERMES_REVISION ${inputs.hermes-agent.rev}
    done

    runHook postInstall
  '';
  passthru = {
    inherit hermesVenv;
    hermesWeb = fixedHermesWeb;
    hermesTui = fixedHermesTui;
    hermesNpmDeps = fixedHermesNpmDeps;
  };
})
