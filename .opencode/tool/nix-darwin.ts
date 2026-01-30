// nix-darwin.ts - Rebuild nix-darwin configuration
// STATUS: BROKEN - nix-darwin rebuild currently failing, use manual rebuild
import { tool } from "@opencode-ai/plugin";

const DOTFILES_DIR = process.env.DOTFILES || `${Bun.env.HOME}/.config/dotfiles`;

export default tool({
  description:
    "[BROKEN] Rebuild and switch to a new nix-darwin configuration. Currently broken - use 'hey rebuild' manually instead.",
  args: {
    show_trace: tool.schema.boolean().optional().describe("Show full trace on errors"),
    check_only: tool.schema
      .boolean()
      .optional()
      .describe("Only check configuration, don't actually rebuild"),
  },
  async execute(args) {
    try {
      if (args.check_only) {
        // Just do a dry-run build check
        const result =
          await Bun.$`cd ${DOTFILES_DIR} && nix build .#darwinConfigurations.MacTraitor-Pro.system --dry-run`.text();
        return `Configuration check passed.\n\n${result}`;
      } else {
        // Do actual rebuild
        const traceFlag = args.show_trace ? "--show-trace" : "";
        const result =
          await Bun.$`cd ${DOTFILES_DIR} && sudo darwin-rebuild --flake .#MacTraitor-Pro switch ${traceFlag}`.text();
        return `Rebuild completed successfully.\n\n${result}`;
      }
    } catch (error: any) {
      return `Rebuild failed:\n${error.message}\n\nStderr: ${error.stderr?.toString() || "none"}`;
    }
  },
});
