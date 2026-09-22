# Nix helper library

Helpers are exposed as `lib.my.*`. Each `.nix` file except `default.nix` receives
`{ self, lib, pkgs, inputs, ... }` and returns attributes merged into that set.

`modules.nix` owns discovery: `.nix` files and directories with `default.nix`
are imported, while `_`-prefixed directories are skipped. `options.nix` owns
`mkOpt`, `mkOpt'`, and `mkBoolOpt`; `nixos.nix` owns host assembly; `platform.nix`
owns platform helpers. Changes to discovery affect modules, hosts, and packages.

Run `hey check lib` for helper changes. Discovery or host-assembly changes also
need the affected `hey check --platform <suite>` because portable evaluation
does not cover every host output.
