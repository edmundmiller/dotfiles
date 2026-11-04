{
  lib,
  nushell,
  python3,
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

    mkdir -p "$out/bin" "$out/libexec/hey"
    cp hey "$out/libexec/hey/hey.nu"
    cp -r hey.d "$out/libexec/hey/hey.d"
    cp agent-run "$out/libexec/hey/agent-run.py"
    cat > "$out/bin/hey" <<EOF
    #!${stdenvNoCC.shell}
    exec ${lib.getExe nushell} "$out/libexec/hey/hey.nu" "\$@"
    EOF
    cat > "$out/bin/agent-run" <<EOF
    #!${stdenvNoCC.shell}
    exec ${lib.getExe python3} "$out/libexec/hey/agent-run.py" "\$@"
    EOF
    chmod +x "$out/bin/hey"
    chmod +x "$out/bin/agent-run"

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
