{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  luajit,
  nodejs,
  lsof,
  sqlite,
}:
stdenvNoCC.mkDerivation {
  pname = "rex-undo";
  version = "0-unstable-2026-11-13";

  src = fetchFromGitHub {
    owner = "lakshaybhushan";
    repo = "rex-undo-extension";
    rev = "2447794e02bbc3ed49cafc41da046278a86d9401";
    hash = "sha256-4tcYEYZvcgk74QMktiD1CvcttPp25//etWe8EBjyb9o=";
  };

  patches = [ ./patches/0001-private-state-directories.patch ];

  # Keep the sibling bin/, hooks/, and rex-undo/ layout used by the Lua loader.
  # install.sh mutates live config and reloads Rex, so never run it from Nix.
  dontBuild = true;
  nativeCheckInputs = [
    luajit
    nodejs
  ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    # KERN_PROCARGS2 needs Apple's Perl. Homebrew Perl has no syscall support.
    export PATH="/usr/bin:/bin:$PATH"
    export XDG_STATE_HOME="$TMPDIR/rex-undo-test-state"
    luajit tests/run.lua "$PWD"
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    dest="$out/share/rex-undo-extension"
    mkdir -p "$dest/lib"
    cp -r rex-undo bin hooks LICENSE README.md STATE_MACHINES.md "$dest/"
    cp lib/watcher.sh "$dest/lib/"
    substituteInPlace "$dest/rex-undo/watcher.lua" \
      --replace-fail '"perl"' '"/usr/bin/perl"' \
      --replace-fail '"lsof"' '"${lsof}/bin/lsof"'
    substituteInPlace "$dest/rex-undo/agents.lua" \
      --replace-fail '"sqlite3"' '"${sqlite}/bin/sqlite3"'
    runHook postInstall
  '';

  meta = {
    description = "Reopen closed Rex panes, tabs, and sessions";
    homepage = "https://github.com/lakshaybhushan/rex-undo-extension";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
  };
}
