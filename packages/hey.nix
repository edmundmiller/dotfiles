{
  lib,
  mise,
  python3,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "hey";
  version = "2.0.0";

  src = ../bin;

  # Don't run any default build phases
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/hey"
    cp hey "$out/bin/hey"
    substituteInPlace "$out/bin/hey" \
      --replace-fail 'exec mise ' 'exec ${lib.getExe mise} '
    cp agent-run "$out/libexec/hey/agent-run.py"
    cat > "$out/bin/agent-run" <<EOF
    #!${stdenvNoCC.shell}
    exec ${lib.getExe python3} "$out/libexec/hey/agent-run.py" "\$@"
    EOF
    chmod +x "$out/bin/hey"
    chmod +x "$out/bin/agent-run"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Compatibility spelling for project-local mise tasks";
    homepage = "https://github.com/edmundmiller/dotfiles";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "hey";
    platforms = platforms.unix;
  };
}
