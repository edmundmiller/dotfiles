{
  lib,
  pkgs,
  inputs,
}:
let
  testLib = lib.extend (_: _: { hm = inputs.home-manager.lib.hm; });
  evaluate =
    isDarwin: overrides:
    (testLib.evalModules {
      specialArgs = { inherit pkgs isDarwin; };
      modules = [
        ../default.nix
        ../native.nix
        {
          # Only the surrounding host options are fixtures. Herdr's options,
          # defaults, files, packages and activation entries are evaluated as-is.
          options = lib.genAttrs [ "user" "dotfiles" "home" "env" "environment" ] (
            _:
            lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
            }
          );
        }
        {
          options.modules.shell.tmux = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = {
              enable = false;
            };
          };
          options.warnings = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          options.home-manager.users = testLib.mkOption {
            default = { };
            type = testLib.types.attrsOf (
              testLib.types.submoduleWith {
                specialArgs.lib = testLib;
                modules = [ { _module.freeformType = testLib.types.attrsOf testLib.types.anything; } ];
              }
            );
          };
          config = {
            user = {
              name = "alice";
              home = "/home/alice";
            };
            dotfiles.configDir = toString ../../../../config;
            modules.shell.herdr = {
              enable = lib.mkDefault true;
              tnote.enable = false;
            };
          };
        }
        { modules.shell.herdr = overrides; }
      ];
    }).config;
  mac = evaluate true { };
  server = evaluate false { };
  headlessMac = evaluate true { native.app.enable = false; };
  desktopLinux = evaluate false { native.app.enable = true; };
  disabled = evaluate true { enable = false; };
  noMachines = evaluate true { native.machines = { }; };
  activation = cfg: cfg.home-manager.users.alice.home.activation or { };
  appEnabled =
    cfg:
    cfg.modules.shell.herdr.backend == "native"
    && cfg.modules.shell.herdr.native.app.enable
    && activation cfg ? herdr-native-core
    && activation cfg ? herdr-native-config
    && cfg.home.configFile ? "herdr-app/mods/dotfiles-dev"
    && builtins.elem "herdr-dev" (map lib.getName cfg.user.packages);
  coreOnly =
    cfg:
    cfg.modules.shell.herdr.backend == "native"
    && !cfg.modules.shell.herdr.native.app.enable
    && cfg.env.HERDR_BACKEND == "native"
    && builtins.attrNames (activation cfg) == [ "herdr-native-core" ]
    && (cfg.home.configFile or { }) == { }
    && (cfg.home.file or { }) == { }
    && (cfg.user.packages or [ ]) == [ ]
    && (cfg.environment.systemPackages or [ ]) == [ ];
in
assert appEnabled mac;
assert appEnabled desktopLinux;
assert coreOnly server;
assert coreOnly headlessMac;
assert mac.modules.shell.herdr.native.machines == { nuc = "emiller@nuc"; };
assert activation mac ? herdr-native-machines;
assert !(activation noMachines ? herdr-native-machines);
assert server.modules.shell.herdr.native.machines == { };
assert headlessMac.modules.shell.herdr.native.machines == { };
assert activation disabled == { };
assert (disabled.home.configFile or { }) == { };
assert (disabled.user.packages or [ ]) == [ ];
true
