{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "opensessions";
  version = "c35e7d3";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "opensessions";
    rev = "c35e7d38410de48de52ca3435703f49fade01546";
    hash = "sha256-U6pS3xLK21Xd6Gb8kd7N08kBQfye95Y8YNWCtyBLOnw=";
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
