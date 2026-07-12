{
  bun,
  git,
  lib,
  python3,
  symlinkJoin,
  writeShellApplication,
}:
let
  command =
    name:
    writeShellApplication {
      inherit name;
      runtimeInputs = [
        bun
        git
        python3
      ];
      text = ''
        exec python3 ${./package_harness.py} ${name} "$@"
      '';
    };
in
symlinkJoin {
  name = "package-harness-1.0.0";
  paths = [
    (command "pkg-list")
    (command "pkg-check")
  ];
  meta = {
    description = "Read-only package maintainer checks";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
