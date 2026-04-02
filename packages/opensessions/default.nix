{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "opensessions";
  version = "9185abf";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "opensessions";
    rev = "9185abf6a363e98849a3a5727ca6865319cf9ea8";
    hash = "sha256-l2oIOQH5OIKcqikv6ZQ9iK4M/QP0fRCMrb28zgU8Mwo=";
  };

  patches = [
    ./patches/0001-add-session-window-and-pane-details.patch
    ./patches/0002-add-show-window-details-config-toggle.patch
    ./patches/0004-harden-startup-and-server-bootstrap.patch
  ];

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
