{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "opensessions";
  version = "c4aa977";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "opensessions";
    rev = "c4aa977983385c37c616decdde52fc0eb69abda5";
    hash = "sha256-4W17zfWq9TJhKleh+Lo7u6LxTcW/OZPk/bkJJMbEyIw=";
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
