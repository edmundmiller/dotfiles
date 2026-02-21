{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "zsh-bench";
  version = "unstable-2024-12-17";

  src = fetchFromGitHub {
    owner = "romkatv";
    repo = "zsh-bench";
    rev = "a3c48d65b9078ee1f8bbd4da8631a8fbc885c52a";
    hash = "sha256-GDYFkObLPTaj+qPVf2sXXqNKkPdD31hfO1bbM5j4lCc=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Install full repo structure — zsh-bench resolves self_dir via ZSH_SCRIPT:A:h
    mkdir -p $out/share/zsh-bench
    cp -r internal configs dbg human-bench zsh-bench $out/share/zsh-bench/
    chmod -R +x $out/share/zsh-bench/internal/ $out/share/zsh-bench/dbg/ 2>/dev/null || true

    # Symlink main script into bin (zsh :A resolves through symlinks)
    mkdir -p $out/bin
    ln -s $out/share/zsh-bench/zsh-bench $out/bin/zsh-bench

    runHook postInstall
  '';

  meta = {
    description = "Benchmark for interactive zsh";
    homepage = "https://github.com/romkatv/zsh-bench";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
