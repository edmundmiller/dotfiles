{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "opensessions";
  version = "0.2.0-alpha.5";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "opensessions";
    rev = "v${_finalAttrs.version}";
    hash = "sha256-OBSp4/fy87BschygMcmOIddchO6CygV70W4brgovitY=";
  };

  # Local patch stack dropped: upstream now includes window-details toggle,
  # session window/pane details, and startup/bootstrap hardening.

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/opensessions"
    cp -R . "$out/share/opensessions/"

    runHook postInstall
  '';

  meta = with lib; {
    description = "tmux session sidebar and command-table plugin";
    homepage = "https://github.com/Ataraxy-Labs/opensessions";
    license = licenses.mit;
    platforms = platforms.unix;
  };
})
