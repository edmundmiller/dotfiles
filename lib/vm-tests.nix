/*
  Shared NixOS VM integration-test harness.

  Absorbs the boilerplate every `modules/<mod>/_tests/<name>-test.nix` repeated:
  building a dotfiles-aware `lib` (so `lib.my` helpers resolve), passing the
  `specialArgs` our modules expect (`inputs`, `isDarwin`), and picking the
  test driver.

  `pkgs.testers.runNixOSTest` pins `nixpkgs.config` itself, which conflicts with
  the per-node overlays/allowUnfree some modules need, so we use the
  `testing-python.nix` driver directly — the same choice the kittylitter and
  herdr tests made by hand.

  Usage:

    { pkgs, inputs }:
    (import ../../../../lib { inherit pkgs inputs; lib = pkgs.lib; }).mkServiceVmTest {
      name = "gatus-endpoints";
      modules = [ ../default.nix ];
      extraConfig = { modules.services.gatus.enable = true; };
      testScript = '' machine.wait_for_unit("gatus.service") '';
    }
*/
{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  mkServiceVmTest =
    {
      name,
      modules ? [ ],
      testScript,
      extraConfig ? { },
      nodeName ? "machine",
      memorySize ? 2048,
      skipTypeCheck ? false,
      specialArgs ? { },
    }:
    let
      dotfilesLib = pkgs.lib.extend (
        self: _super: {
          my = import ./. {
            inherit pkgs inputs;
            lib = self;
          };
        }
      );

      nixosTesting = import "${pkgs.path}/nixos/lib/testing-python.nix" {
        inherit pkgs;
        inherit (pkgs.stdenv.hostPlatform) system;
      };
    in
    nixosTesting.runTest {
      inherit name testScript skipTypeCheck;

      node.specialArgs = {
        lib = dotfilesLib;
        inherit inputs;
        isDarwin = false;
      }
      // specialArgs;

      nodes.${nodeName} = {
        imports = modules ++ [ extraConfig ];
        virtualisation.memorySize = lib.mkDefault memorySize;
      };
    };

  /*
    Scan `root` for `<module>/_tests/<name>-test.nix` and import each as a
    check named `vm-<module>-<name>-test`.

    Only `-test.nix` files under `_tests/` are picked up, so pure-eval
    assertion files (`eval-*.nix`, `config-check.nix`) stay opt-in via explicit
    `checks` entries. Every discovered file must take `{ pkgs, inputs }` and
    return a derivation.
  */
  discoverVmTests =
    root:
    let
      inherit (builtins)
        readDir
        pathExists
        concatMap
        attrNames
        ;
      inherit (lib)
        hasSuffix
        hasPrefix
        removeSuffix
        nameValuePair
        listToAttrs
        ;

      # `dir` must stay a Nix *path*, not a string: importing a stringified
      # path re-roots relative imports inside the test at the store root, so
      # `../../../../lib` becomes /nix/store/lib.
      testsIn =
        prefix: dir:
        let
          entries = readDir dir;
          testDir = dir + "/_tests";

          own = lib.optionals (pathExists testDir) (
            map (f: nameValuePair "vm-${prefix}-${removeSuffix ".nix" f}" (testDir + "/${f}")) (
              lib.filter (f: hasSuffix "-test.nix" f) (attrNames (readDir testDir))
            )
          );

          children = lib.filter (n: entries.${n} == "directory" && !(hasPrefix "_" n)) (attrNames entries);
        in
        own ++ concatMap (n: testsIn "${prefix}-${n}" (dir + "/${n}")) children;

      topLevel = lib.filter (n: (readDir root).${n} == "directory" && !(hasPrefix "_" n)) (
        attrNames (readDir root)
      );
    in
    listToAttrs (
      map (nv: nameValuePair nv.name (import nv.value { inherit pkgs inputs; })) (
        concatMap (n: testsIn n (root + "/${n}")) topLevel
      )
    );
}
