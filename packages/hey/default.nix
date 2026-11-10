{
  clang,
  coreutils,
  git,
  jq,
  lib,
  mise,
  # An absolute mise outside the store, such as Homebrew's.
  misePath ? lib.getExe mise,
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
  nativeCheckInputs = [
    git
    jq
    python3
  ];
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    bash build hey ${misePath}
    bash build hey-task ${misePath} task-main.bend
    bash build hey-desktop ${misePath} desktop-main.bend
    bash build hey-macos ${misePath} macos-main.bend ${lib.getExe' coreutils "mv"}
    bash build hey-hermes ${misePath} hermes-main.bend
    bash build hey-login ${misePath} login-main.bend
    bash build hey-prepare ${misePath} prepare-main.bend
    bash build hey-nuc ${misePath} nuc-main.bend
    bash build hey-snapshot ${misePath} snapshot-main.bend
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    # Exercise the same native boundary with a disposable mise executable.
    HEY_TEST_LAUNCHER=${../../bin/hey} python3 -B test_hey.py
    python3 -B test_process.py
    python3 -B test_posix.py
    python3 -B test_gateway_status.py
    python3 -B test_tasks.py
    python3 -B test_task_text.py
    python3 -B test_desktop_tasks.py
    python3 -B test_macos_tasks.py
    python3 -B test_hermes_tasks.py
    python3 -B test_login_tasks.py
    python3 -B test_prepare_tasks.py
    python3 -B test_nuc_workers.py
    HEY_TEST_NUC_PRUNER=${../../bin/prune-nuc-deploy-snapshots} \
      HEY_TEST_NUC_REVISION_WRITER=${../../bin/write-nuc-deploy-revision} \
      python3 -B test_nuc_tasks.py
    HEY_TEST_NUC_PRUNER=${../../bin/prune-nuc-deploy-snapshots} python3 -B test_nuc_snapshots.py
    python3 -B test_evaluation_lock.py
    python3 -B test_system_guards.py
    python3 -B test_sudo_prompt.py
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/hey"
    cp hey "$out/bin/hey"
    cp hey-task "$out/libexec/hey/task"
    cp hey-desktop "$out/libexec/hey/desktop"
    cp hey-macos "$out/libexec/hey/macos"
    cp hey-hermes "$out/libexec/hey/hermes"
    cp hey-login "$out/libexec/hey/login"
    cp hey-prepare "$out/libexec/hey/prepare"
    cp hey-nuc "$out/libexec/hey/nuc"
    cp hey-snapshot "$out/libexec/hey/snapshot"
    ln -s "$out/libexec/hey/task" "$out/bin/hey-task"
    ln -s "$out/libexec/hey/desktop" "$out/bin/hey-task-desktop"
    ln -s "$out/libexec/hey/macos" "$out/bin/hey-task-macos"
    ln -s "$out/libexec/hey/hermes" "$out/bin/hey-task-hermes"
    ln -s "$out/libexec/hey/login" "$out/bin/hey-task-login"
    ln -s "$out/libexec/hey/prepare" "$out/bin/hey-task-prepare"
    ln -s "$out/libexec/hey/nuc" "$out/bin/hey-task-nuc"
    ln -s "$out/libexec/hey/snapshot" "$out/bin/hey-task-snapshot"
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
