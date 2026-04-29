{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  makeWrapper,
  tmux,
  git,
}:

stdenv.mkDerivation {
  pname = "jmux";
  version = "0.15.0";

  src = fetchFromGitHub {
    owner = "jarredkenny";
    repo = "jmux";
    rev = "v0.15.0";
    hash = "sha256-QLytzMzDUKdJddQ9Qao2xSO0C7jDfQIwOeJNNZy6pA4=";
  };

  patches = [
    ./patches/0001-patch-configurable-prefix-and-new-session-key.patch
    ./patches/0002-patch-handle-batched-prefix-input-chunks.patch
    ./patches/0003-patch-update-help-text-for-Prefix-keybindings.patch
    ./patches/0004-patch-add-Show-Welcome-palette-action.patch
    ./patches/0005-patch-show-resolved-prefix-in-help-and-hunk-hints.patch
    ./patches/0006-test-cover-resolved-prefix-label-in-diff-panel-hints.patch
    ./patches/0007-test-cover-resolved-prefix-in-help-output.patch
  ];

  nativeBuildInputs = [
    bun
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)
    bun install --frozen-lockfile

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    appDir=$out/lib/jmux
    mkdir -p "$appDir" "$out/bin"
    cp -r bin src config skills node_modules package.json bun.lock "$appDir"/

    makeWrapper ${bun}/bin/bun $out/bin/jmux \
      --set-default JMUX_PREFIX_KEY C-c \
      --set-default JMUX_NEW_SESSION_KEY M \
      --add-flags "$appDir/bin/jmux" \
      --prefix PATH : ${
        lib.makeBinPath [
          tmux
          git
        ]
      }

    runHook postInstall
  '';

  meta = with lib; {
    description = "jmux wrapped to honor Ctrl-c and keep prefix+n on next-window in this dotfiles setup";
    homepage = "https://github.com/jarredkenny/jmux";
    license = licenses.mit;
    mainProgram = "jmux";
    platforms = platforms.unix;
  };
}
