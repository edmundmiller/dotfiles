{
  lib,
  stdenvNoCC,
  jujutsu,
  gum,
  makeWrapper,
}:

stdenvNoCC.mkDerivation {
  pname = "jw";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Install main script
    mkdir -p $out/bin
    cp jw $out/bin/jw
    chmod +x $out/bin/jw

    # Install lib directory
    mkdir -p $out/lib/jw
    cp -r lib/* $out/lib/jw/

    # Patch the script to use correct lib path
    substituteInPlace $out/bin/jw \
      --replace 'LIB_DIR="''${SCRIPT_DIR}/lib"' 'LIB_DIR="'"$out"'/lib/jw"'

    # Wrap with dependencies in PATH
    wrapProgram $out/bin/jw \
      --prefix PATH : ${
        lib.makeBinPath [
          jujutsu
          gum
        ]
      }

    runHook postInstall
  '';

  meta = with lib; {
    description = "JJ Workspace management for parallel agents";
    longDescription = ''
      A CLI tool for managing Jujutsu (jj) workspaces.
      Designed for running AI agents (Claude, OpenCode) in parallel.
    '';
    homepage = "https://github.com/edmundmiller/dotfiles";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "jw";
    platforms = platforms.unix;
  };
}
