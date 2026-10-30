{
  lib,
  pkgs,
  inputs,
}:
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
    touch "$out"
  ''
