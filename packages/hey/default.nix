{
  clang,
  lib,
  mise,
  my,
  python3,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "hey";
  version = "2.1.0";

  src = ./.;

  nativeBuildInputs = [
    clang
    my.bend
  ];
  nativeCheckInputs = [ python3 ];
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    bash build hey ${lib.getExe mise}
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    # Exercise the same native boundary with a disposable mise executable.
    HEY_TEST_LAUNCHER=${../../bin/hey} python3 -B test_hey.py
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/hey"
    cp hey "$out/bin/hey"
    cp ${../../bin/agent-run} "$out/libexec/hey/agent-run.py"
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
    platforms = my.bend.meta.platforms;
  };
}
