{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.ai;
in
{
  options.modules.shell.ai = with types; {
    enable = mkBoolOpt false;
    enableClaude = mkBoolOpt false;
    enableCodex = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      # (unstable.llm.withPlugins [
      #   # inputs.llm-prompt.packages.${system}.llm-prompt
      #   # my.llm-claude-3
      # ])
      unstable.chatblade
      unstable.aichat
    ];

    # Install Claude CLI via npm if enabled
    home-manager.users.${config.user.name} = { lib, ... }: mkMerge [
      (mkIf cfg.enableClaude {
        home.activation.install-claude-cli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          npm_bin="${pkgs.nodejs}/bin/npm"
          pnpm_bin="${pkgs.pnpm}/bin/pnpm"
          
          # Try pnpm first, fall back to npm
          if [ -x "$pnpm_bin" ]; then
            package_manager="$pnpm_bin"
          else
            package_manager="$npm_bin"
          fi
          
          if [ -x "$package_manager" ]; then
            if ! command -v claude &> /dev/null; then
              echo "Installing Claude CLI (@anthropic-ai/claude-code)..."
              "$package_manager" install -g @anthropic-ai/claude-code \
                || echo "Warning: Failed to install Claude CLI; claude command may be unavailable."
            else
              echo "Claude CLI already installed"
            fi
          fi
        '';
      })
      
      (mkIf cfg.enableCodex {
        home.activation.install-codex-cli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          npm_bin="${pkgs.nodejs}/bin/npm"
          pnpm_bin="${pkgs.pnpm}/bin/pnpm"
          
          # Try pnpm first, fall back to npm
          if [ -x "$pnpm_bin" ]; then
            package_manager="$pnpm_bin"
          else
            package_manager="$npm_bin"
          fi
          
          if [ -x "$package_manager" ]; then
            if ! command -v codex &> /dev/null; then
              echo "Installing Codex CLI (@openai/codex)..."
              "$package_manager" install -g @openai/codex \
                || echo "Warning: Failed to install Codex CLI; codex command may be unavailable."
            else
              echo "Codex CLI already installed"
            fi
          fi
        '';
      })
    ];
  };
}
