# modules/dev/node.nix --- https://nodejs.org/en/
#
# JS is one of those "when it's good, it's alright, when it's bad, it's a
# disaster" languages.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.dev.node;
  node = pkgs.nodejs_latest;
in
{
  options.modules.dev.node = {
    enable = mkBoolOpt false;
    enableGlobally = mkBoolOpt false;
    useFnm = mkBoolOpt false; # Use fnm (Fast Node Manager) for Node version management
  };

  config = mkIf cfg.enable (mkMerge [
    # fnm (Fast Node Manager) shell initialization with lazy loading (~30ms savings)
    # Based on: https://willhbr.net/2025/01/06/lazy-load-command-completions-for-a-faster-shell-startup/
    (mkIf cfg.useFnm {
      modules.shell.zsh.rcInit = ''
        # fnm - Fast Node Manager (lazy loaded)
        function fnm {
          unfunction fnm node npm npx pnpm yarn
          eval "$(command fnm env --use-on-cd)"
          command fnm "$@"
        }
        # Create stub functions for node/npm that trigger fnm init
        for cmd in node npm npx pnpm yarn; do
          eval "function $cmd { fnm; command $cmd \"\$@\"; }"
        done
      '';
    })

    (mkIf cfg.enableGlobally {
      user.packages =
        with pkgs;
        [
          bun
          yarn
          nodePackages_latest.pnpm
        ]
        ++ lib.optionals (!cfg.useFnm) [ node ];

      # Run locally installed bin-script, e.g. n coffee file.coffee
      environment.shellAliases = {
        n = ''PATH="$(${node}/bin/npm bin):$PATH"'';
        ya = "yarn";
      };

      env.BUN_INSTALL = "$HOME/.bun";
      env.PATH = mkAfter [
        "$(${pkgs.yarn}/bin/yarn global bin)"
        "$HOME/.bun/bin" # bun global packages
      ];
    })

    {
      env.NPM_CONFIG_USERCONFIG = "$XDG_CONFIG_HOME/npm/config";
      env.NPM_CONFIG_CACHE = "$XDG_CACHE_HOME/npm";
      env.NPM_CONFIG_TMP = "$XDG_RUNTIME_DIR/npm";
      env.NPM_CONFIG_PREFIX = "$XDG_CACHE_HOME/npm";
      env.NODE_REPL_HISTORY = "$XDG_CACHE_HOME/node/repl_history";

      # Add npm global bin to PATH
      env.PATH = [ "$XDG_CACHE_HOME/npm/bin" ];

      home.configFile."npm/config".text = ''
        cache=$XDG_CACHE_HOME/npm
        prefix=$XDG_DATA_HOME/npm
      '';
    }
  ]);
}
