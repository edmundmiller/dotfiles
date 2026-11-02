{
  lib,
  pkgs,
  inputs,
}:
let
  t3 = import ../_t3-source.nix { inherit pkgs; };
in
assert import ./native-module.nix { inherit lib pkgs inputs; };
pkgs.runCommand "herdr-native-tests"
  {
    nativeBuildInputs = [
      (pkgs.python3.withPackages (ps: [ ps.pytest ]))
      pkgs.bash
      pkgs.git
      pkgs.jq
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnused
      pkgs.gnugrep
      pkgs.zsh
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME" source/bin source/config/herdr source/tests
    cp ${../../../../bin/herdr-studios} source/bin/herdr-studios
    cp -R ${../../../../config/herdr/native} source/config/herdr/native
    cp ${../../../../config/herdr/aliases.zsh} source/config/herdr/aliases.zsh
    cp ${../../../../tests/test_herdr_native_config.py} source/tests/test_herdr_native_config.py
    cp ${../../../../tests/test_herdr_native_dev.py} source/tests/test_herdr_native_dev.py
    cp ${../../../../tests/test_herdr_studios_native.py} source/tests/test_herdr_studios_native.py
    chmod -R u+w source
    cd source
    python3 -m pytest -q tests
    found=$(ls -1 ${t3.src}/mods | grep '^t3-' | sort)
    expected=$(printf '%s\n' ${lib.escapeShellArgs (builtins.sort builtins.lessThan t3.mods)} | sort)
    if [ "$found" != "$expected" ]; then
      echo "herdr-t3 mods/t3-* drifted from modules/shell/herdr/_t3-source.nix" >&2
      printf 'found:\n%s\nexpected:\n%s\n' "$found" "$expected" >&2
      exit 1
    fi
    test -f ${t3.src}/layouts/herdr-t3.json
    test -f ${t3.src}/layouts/herdr-t3.svg
    test -f ${t3.src}/extras/themes/herdr-t3.json
    test -d ${t3.src}/extras/mods/pulls-review
    jq -e \
      '.["layout:herdr-t3"]["cmd-shift-b"] == "t3-chrome.sidebar" and .["layout:herdr-t3"]["cmd-shift-a"] == "t3-tabs.view"' \
      ${t3.src}/keys.json >/dev/null
    touch "$out"
  ''
