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
  t3Off = evaluate true { native.t3.enable = false; };
  t3 = import ../_t3-source.nix { inherit pkgs; };
  activation = cfg: cfg.home-manager.users.alice.home.activation or { };
  activationText = cfg: (activation cfg).herdr-native-config.data;
  deployedMods =
    cfg:
    map (lib.removePrefix "herdr-app/mods/") (
      lib.filter (name: lib.hasPrefix "herdr-app/mods/" name) (builtins.attrNames cfg.home.configFile)
    );
  t3FileSource = name: "${t3.src}/${name}";
  t3Links = {
    "herdr-app/layouts/herdr-t3.json" = t3FileSource "layouts/herdr-t3.json";
    "herdr-app/layouts/herdr-t3.svg" = t3FileSource "layouts/herdr-t3.svg";
    "herdr-app/themes/herdr-t3.json" = t3FileSource "extras/themes/herdr-t3.json";
  }
  // lib.listToAttrs (
    map (name: {
      name = "herdr-app/mods/${name}";
      value = t3FileSource "mods/${name}";
    }) t3.mods
  );
  linksT3 =
    cfg:
    lib.all (name: (cfg.home.configFile.${name}.source or null) == t3Links.${name}) (
      builtins.attrNames t3Links
    );
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
assert linksT3 mac;
assert linksT3 desktopLinux;
assert lib.intersectLists t3.mods (deployedMods mac) == t3.mods;
assert lib.elem "dotfiles-dev" (deployedMods mac);
assert lib.elem "dotfiles-prefix" (deployedMods mac);
assert mac.home.configFile ? "herdr-app/layouts/dotfiles.json";
assert !(mac.home.configFile ? "herdr-app/mods/pulls-review");
assert lib.hasInfix "--extra-keys" (activationText mac);
assert lib.hasInfix "keys.json" (activationText mac);
assert appEnabled t3Off;
assert t3Off.home.configFile ? "herdr-app/layouts/dotfiles.json";
assert t3Off.home.configFile ? "herdr-app/mods/dotfiles-dev";
assert !(t3Off.home.configFile ? "herdr-app/layouts/herdr-t3.json");
assert !(t3Off.home.configFile ? "herdr-app/mods/t3-focus");
assert !(lib.hasInfix "--extra-keys" (activationText t3Off));
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
