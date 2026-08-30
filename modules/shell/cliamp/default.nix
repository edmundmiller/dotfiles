{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.cliamp;
  inherit (config.dotfiles) configDir;
  nightriderSource = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/HANCORE-linux/cliamp-plugin-nightrider/d8d338fc56c4676edacf0d396b627d99bbc941ed/nightrider.lua";
    hash = "sha256-cqDGm8a95OP/0YXV/06cK3xt5oz7rve19eI7QhX74FM=";
  };
in
{
  options.modules.shell.cliamp = {
    enable = mkBoolOpt false;
    package = mkOpt types.package pkgs.cliamp;
    nightrider.enable = mkBoolOpt true;
  };

  config = mkIf cfg.enable {
    user.packages = [ cfg.package ];

    # CLIamp updates config.toml at runtime, so bootstrap a writable copy rather
    # than linking the tracked template from the read-only Nix store.
    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.activation.cliamp-bootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          cliamp_dir="$HOME/.config/cliamp"
          config_target="$cliamp_dir/config.toml"
          plugin_dir="$cliamp_dir/plugins"
          trust_target="$plugin_dir/.trust.json"

          ${pkgs.coreutils}/bin/mkdir -p "$plugin_dir"

          if [ ! -e "$config_target" ]; then
            ${pkgs.coreutils}/bin/install -m 0600 \
              ${escapeShellArg "${configDir}/cliamp/config.toml"} \
              "$config_target"
          fi

          ${optionalString cfg.nightrider.enable ''
            ${pkgs.coreutils}/bin/install -m 0644 \
              ${escapeShellArg "${nightriderSource}"} \
              "$plugin_dir/nightrider.lua"

            ${pkgs.python3}/bin/python3 - "$plugin_dir/nightrider.lua" "$trust_target" <<'PY'
            import hashlib
            import json
            import os
            import pathlib
            import sys
            import tempfile

            plugin = pathlib.Path(sys.argv[1])
            target = pathlib.Path(sys.argv[2])
            try:
                manifest = json.loads(target.read_text())
            except (FileNotFoundError, json.JSONDecodeError):
                manifest = {"version": 1, "plugins": {}}

            if not isinstance(manifest, dict):
                manifest = {"version": 1, "plugins": {}}
            manifest["version"] = 1
            plugins = manifest.setdefault("plugins", {})
            if not isinstance(plugins, dict):
                plugins = manifest["plugins"] = {}

            digest = hashlib.sha256(plugin.read_bytes()).hexdigest()
            plugins["nightrider"] = digest
            # CLIamp 1.63.2 loads single-file plugins by stem but its list
            # command checks the full filename. Keep both until that fix ships.
            plugins["nightrider.lua"] = digest

            fd, temporary = tempfile.mkstemp(dir=target.parent, prefix=".trust.")
            try:
                with os.fdopen(fd, "w") as handle:
                    json.dump(manifest, handle, indent=2)
                    handle.write("\n")
                os.chmod(temporary, 0o600)
                os.replace(temporary, target)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
            PY
          ''}
        '';
      };
  };
}
