{
  lib,
  stdenvNoCC,
  just,
  installShellFiles,
}:

stdenvNoCC.mkDerivation {
  pname = "hey";
  version = "1.0.0";

  src = ../bin;

  nativeBuildInputs = [
    just
    installShellFiles
  ];

  buildInputs = [ just ];

  # Don't run any default build phases
  dontConfigure = true;
  dontBuild = false;

  buildPhase = ''
    runHook preBuild

    # Generate zsh completion using just
    # The hey script uses #!/usr/bin/env -S just --justfile shebang
    # so we call just directly with the hey file as the justfile
    ${just}/bin/just --justfile hey --completions zsh > _hey

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install hey script
    mkdir -p $out/bin
    cp hey $out/bin/hey
    chmod +x $out/bin/hey

    # Install hey.d modules
    cp -r hey.d $out/bin/hey.d

    # Install zsh completion to standard location
    installShellCompletion --zsh _hey

    runHook postInstall
  '';

  meta = with lib; {
    description = "A modular interface to nix-darwin/nixos operations using JustScripts";
    homepage = "https://github.com/edmundmiller/dotfiles";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "hey";
    platforms = platforms.unix;
  };
}
