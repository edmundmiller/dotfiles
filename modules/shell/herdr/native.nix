{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.shell.herdr;
  nativeSource = "${config.dotfiles.configDir}/herdr/native";
  t3 = import ./_t3-source.nix { inherit pkgs; };
  personalMods = [
    "dotfiles-dev"
    "dotfiles-prefix"
  ];
  # herdr-t3 ships its own mod names. Never let a pin replace the dotfiles mods.
  t3ConfigFiles =
    lib.listToAttrs (
      map (name: {
        name = "herdr-app/mods/${name}";
        value.source = "${t3.src}/mods/${name}";
      }) t3.mods
    )
    // {
      "herdr-app/layouts/herdr-t3.json".source = "${t3.src}/layouts/herdr-t3.json";
      "herdr-app/layouts/herdr-t3.svg".source = "${t3.src}/layouts/herdr-t3.svg";
      "herdr-app/themes/herdr-t3.json".source = "${t3.src}/extras/themes/herdr-t3.json";
    };
  herdrDev = pkgs.writeShellScriptBin "herdr-dev" ''
    export PATH=${lib.escapeShellArg "${config.user.home}/.local/bin"}:$PATH
    export HERDR_APP_COMMAND=${lib.escapeShellArg cfg.native.appCommand}
    exec ${pkgs.python3}/bin/python3 ${nativeSource}/herdr-dev.py "$@"
  '';
in
assert lib.intersectLists t3.mods personalMods == [ ];
assert builtins.all (lib.hasPrefix "t3-") t3.mods;
{
  options.modules.shell.herdr.native = {
    app.enable = lib.my.mkBoolOpt isDarwin;
    machines = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = lib.optionalAttrs (isDarwin && cfg.native.app.enable) { nuc = "emiller@nuc"; };
      description = ''
        Named SSH targets to register with the default hc session on activation.
        Existing connections must match; other machines are never removed.
        Unreachable machines are retried on the next activation, without installing hc remotely.
      '';
    };
    appCommand = lib.mkOption {
      type = lib.types.str;
      default = "${config.user.home}/.local/bin/herdr-app";
      description = "Official installer-owned native Herdr executable. Nix never modifies its signed bundle.";
    };
    coreCommand = lib.mkOption {
      type = lib.types.str;
      default = "${config.user.home}/.local/bin/hc";
      description = "Official installer-owned herdr-core executable.";
    };
    t3.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Link the pinned herdr-t3 layout, its mods and theme beside the
        dotfiles layout, and merge its layout keybindings. Applies only
        when the native app configuration is enabled.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.backend == "native") (
    lib.mkMerge [
      {
        env.HERDR_BACKEND = "native";
        warnings = lib.optional (cfg.projects.enable || cfg.vercelSandbox.enable) ''
          Herdr native does not load legacy Projects or Vercel Sandbox plugins.
          Their configuration is retained for backend = "legacy"; see config/herdr/README.md.
        '';
        home-manager.users.${config.user.name} = { lib, ... }: {
          home.activation.herdr-native-core = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if [ ! -x ${lib.escapeShellArg cfg.native.coreCommand} ]; then
              echo 'herdr: hc missing; install with https://releases.herdr.dev/core/install.sh' >&2
            fi
          '';
        };
      }
      (lib.mkIf (cfg.native.machines != { }) {
        home-manager.users.${config.user.name} = { lib, ... }: {
          home.activation.herdr-native-machines = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            if [ -x ${lib.escapeShellArg cfg.native.coreCommand} ]; then
              PATH=${lib.makeBinPath [ pkgs.openssh ]}:$PATH \
                ${pkgs.coreutils}/bin/env -u HC_SOCKET HC_SESSION=default \
                ${pkgs.python3}/bin/python3 ${nativeSource}/reconcile-machines.py \
                --core ${lib.escapeShellArg cfg.native.coreCommand} \
                --machines ${pkgs.writeText "herdr-machines.json" (builtins.toJSON cfg.native.machines)} \
                || echo 'herdr: machine registration incomplete; retry activation when SSH is available' >&2
            fi
          '';
        };
      })
      (lib.mkIf cfg.native.app.enable {
        user.packages = [ herdrDev ] ++ lib.optional cfg.tnote.enable pkgs.my.tnote;
        environment.systemPackages = [ herdrDev ] ++ lib.optional cfg.tnote.enable pkgs.my.tnote;
        home.file.".local/bin/rift".source = lib.getExe pkgs.my.rift;

        # The app owns its shipped mods, layouts, typings and all runtime state.
        # Each personal or pinned mod is one directory symlink so relative
        # imports and SVG files resolve inside that store directory.
        home.configFile = {
          "herdr-app/mods/dotfiles-dev".source = "${nativeSource}/mods/dotfiles-dev";
          "herdr-app/mods/dotfiles-prefix".source = "${nativeSource}/mods/dotfiles-prefix";
          "herdr-app/layouts/dotfiles.json".source = "${nativeSource}/layouts/dotfiles.json";
        }
        // lib.optionalAttrs cfg.native.t3.enable t3ConfigFiles;
        home-manager.users.${config.user.name} = { lib, ... }: {
          home.activation.herdr-native-config = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${pkgs.python3}/bin/python3 ${nativeSource}/reconcile-config.py \
              --home "$HOME/.config/herdr-app" --source ${nativeSource} \
              --core ${lib.escapeShellArg cfg.native.coreCommand} ${lib.optionalString cfg.native.t3.enable "--extra-keys ${lib.escapeShellArg "${t3.src}/keys.json"}"}
            if [ ! -x ${lib.escapeShellArg cfg.native.appCommand} ]; then
              echo 'herdr: app missing; install with https://releases.herdr.dev/app/install.sh' >&2
            fi
          '';
        };
      })
    ]
  );
}
