{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.opencode;
  inherit (config.dotfiles) configDir;
  opencodeConfigDir = "${config.user.home}/.config/opencode";
in
{
  options.modules.shell.opencode = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # On Darwin, opencode is installed via homebrew for better integration
    user.packages = with pkgs;
      lib.optionals (!pkgs.stdenv.isDarwin) [ unstable.opencode ];

    home.configFile = {
      # OpenCode uses XDG config directory: ~/.config/opencode/
      # These can be symlinked (no node module resolution needed)
      "opencode/opencode.jsonc".source = "${configDir}/opencode/opencode.jsonc";
      "opencode/AGENTS.md".source = "${configDir}/opencode/AGENTS.md";
      "opencode/GLOBAL_INSTRUCTIONS.md".source = "${configDir}/opencode/GLOBAL_INSTRUCTIONS.md";
      "opencode/rules".source = "${configDir}/opencode/rules";
      "opencode/agent".source = "${configDir}/opencode/agent";
      "opencode/command".source = "${configDir}/opencode/command";
      "opencode/skills".source = "${configDir}/opencode/skills";
      "opencode/ast-grep".source = "${configDir}/opencode/ast-grep";

      # Tool files need to be COPIED (not symlinked) so they can
      # resolve @opencode-ai/plugin from ~/.config/opencode/node_modules/
      # When symlinked to Nix store, Node.js can't find the modules.
      #
      # Plugin directory is NOT managed by nix - users install plugins manually
      # to ~/.config/opencode/plugin/ (supports TypeScript plugins that need build steps)
    };

    # Use home-manager activation to copy tool files
    # This ensures files are at the actual path where node_modules can be resolved
    home-manager.users.${config.user.name} = { lib, ... }: {
      home.activation.opencode-setup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        # Copy tool files (not symlink) so Node can resolve modules
        ${pkgs.rsync}/bin/rsync -a --delete \
          "${configDir}/opencode/tool/" \
          "${opencodeConfigDir}/tool/"

        # Ensure plugin directory exists (user-managed, not synced)
        mkdir -p "${opencodeConfigDir}/plugin"

        # Copy package.json for bun/npm install
        cp -f "${configDir}/opencode/package.json" "${opencodeConfigDir}/package.json"

        # Install dependencies if bun is available
        if command -v bun &> /dev/null; then
          cd "${opencodeConfigDir}" && bun install --silent 2>/dev/null || true
        fi
      '';
    };
  };
}
