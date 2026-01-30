{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.editors.file-associations;

  # Map editor names to bundle IDs
  bundleIds = {
    zed = "dev.zed.Zed";
    neovide = "com.neovide.neovide";
    vscode = "com.microsoft.VSCode";
  };

  bundleId = bundleIds.${cfg.editor} or cfg.editor;

  # Common file associations configuration
  dutiConfig = ''
    # ${cfg.editor} as default text editor
    # Format: bundle_id UTI role

    # Text files by UTI
    ${bundleId} public.plain-text all
    ${bundleId} public.text all
    ${bundleId} public.source-code all
    ${bundleId} public.script all
    ${bundleId} public.shell-script all
    ${bundleId} public.python-script all
    ${bundleId} public.ruby-script all
    ${bundleId} public.perl-script all
    ${bundleId} public.json all
    ${bundleId} public.xml all
    ${bundleId} public.html all
    ${bundleId} com.netscape.javascript-source all
    ${bundleId} net.daringfireball.markdown all

    # File extensions
    ${bundleId} .txt all
    ${bundleId} .md all
    ${bundleId} .markdown all
    ${bundleId} .nix all
    ${bundleId} .log all
    ${bundleId} .conf all
    ${bundleId} .config all
    ${bundleId} .toml all
    ${bundleId} .yaml all
    ${bundleId} .yml all
    ${bundleId} .json all
    ${bundleId} .js all
    ${bundleId} .ts all
    ${bundleId} .jsx all
    ${bundleId} .tsx all
    ${bundleId} .py all
    ${bundleId} .rb all
    ${bundleId} .sh all
    ${bundleId} .bash all
    ${bundleId} .zsh all
    ${bundleId} .fish all
    ${bundleId} .c all
    ${bundleId} .h all
    ${bundleId} .cpp all
    ${bundleId} .hpp all
    ${bundleId} .rs all
    ${bundleId} .go all
    ${bundleId} .java all
    ${bundleId} .swift all
    ${bundleId} .m all
    ${bundleId} .mm all
    ${bundleId} .php all
    ${bundleId} .lua all
    ${bundleId} .pl all
    ${bundleId} .env all
    ${bundleId} .gitignore all
    ${bundleId} .gitconfig all
    ${bundleId} .editorconfig all
    ${bundleId} .dockerfile all
    ${bundleId} .makefile all
    ${bundleId} .html all
    ${bundleId} .htm all
    ${bundleId} .css all
    ${bundleId} .scss all
    ${bundleId} .sass all
    ${bundleId} .less all
    ${bundleId} .xml all
    ${bundleId} .csv all
    ${bundleId} .sql all
  '';
in
{
  options.modules.editors.file-associations = {
    enable = mkBoolOpt false;
    editor = mkOpt types.str "zed";
  };

  config = mkIf cfg.enable (mkMerge [
    # Add duti package (macOS only)
    (mkIf pkgs.stdenv.isDarwin {
      environment.systemPackages = with pkgs; [ duti ];

      # Configure file associations using duti
      system.activationScripts.dutiConfiguration.text = ''
        echo "Configuring default text editor file associations for ${cfg.editor}..."

        # Create duti configuration
        cat > /tmp/duti-config.txt <<EOF
        ${dutiConfig}
        EOF

        # Apply the duti configuration as the primary user
        if command -v duti >/dev/null 2>&1; then
          sudo -u ${config.system.primaryUser or "$(whoami)"} duti /tmp/duti-config.txt
          echo "File associations configured for ${cfg.editor}"
        else
          echo "Warning: duti not found, skipping file associations"
        fi

        # Clean up
        rm -f /tmp/duti-config.txt
      '';
    })
  ]);
}
