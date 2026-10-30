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
  herdrDev = pkgs.writeShellScriptBin "herdr-dev" ''
    export PATH=${lib.escapeShellArg "${config.user.home}/.local/bin"}:$PATH
    export HERDR_APP_COMMAND=${lib.escapeShellArg cfg.native.appCommand}
    exec ${pkgs.python3}/bin/python3 ${nativeSource}/herdr-dev.py "$@"
  '';
in
{
  options.modules.shell.herdr.native = {
    app.enable = lib.my.mkBoolOpt isDarwin;
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
      (lib.mkIf cfg.native.app.enable {
        user.packages = [ herdrDev ] ++ lib.optional cfg.tnote.enable pkgs.my.tnote;
        environment.systemPackages = [ herdrDev ] ++ lib.optional cfg.tnote.enable pkgs.my.tnote;
        home.file.".local/bin/rift".source = lib.getExe pkgs.my.rift;

        # The app owns its shipped mods, layouts, typings and all runtime state.
        home.configFile."herdr-app/mods/dotfiles-dev".source = "${nativeSource}/mods/dotfiles-dev";
        home-manager.users.${config.user.name} = { lib, ... }: {
          home.activation.herdr-native-config = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${pkgs.python3}/bin/python3 ${nativeSource}/reconcile-config.py \
              --home "$HOME/.config/herdr-app" --source ${nativeSource} \
              --core ${lib.escapeShellArg cfg.native.coreCommand}
            if [ ! -x ${lib.escapeShellArg cfg.native.appCommand} ]; then
              echo 'herdr: app missing; install with https://releases.herdr.dev/app/install.sh' >&2
            fi
          '';
        };
      })
    ]
  );
}
