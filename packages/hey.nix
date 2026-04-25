{
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "hey";
  version = "1.0.0";

  src = ../bin;

  # Don't run any default build phases
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Install hey script
    mkdir -p $out/bin
    cp hey $out/bin/hey
    chmod +x $out/bin/hey

    # Install hey.d modules
    cp -r hey.d $out/bin/hey.d

    runHook postInstall
  '';

  meta = with lib; {
    description = "A modular interface to nix-darwin/nixos operations using Nushell";
    homepage = "https://github.com/edmundmiller/dotfiles";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "hey";
    platforms = platforms.unix;
  };
}
