{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "opensessions";
  version = "be4ed7f";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "opensessions";
    rev = "be4ed7ff399640c3c95ff976905e4d362c404478";
    hash = "sha256-4c+KSEUYxggi7RpuPLzC/OwEDL0BkQ++ahTdpi0TVYs=";
  };

  patches = [
    ./patches/0001-add-session-window-and-pane-details.patch
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
