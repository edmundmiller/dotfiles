/**
 * gitbutler-guard Extension
 *
 * Blocks git write commands in GitButler workspaces.
 * When a repo has GitButler active (.git/gitbutler/ exists),
 * git write operations must use `but` equivalents instead.
 *
 * Read-only git commands (log, diff, show, blame) are always allowed.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";
import { existsSync } from "node:fs";
import { execSync } from "node:child_process";

// Git write commands that should use `but` equivalents
const BLOCKED_COMMANDS: { pattern: RegExp; replacement: string }[] = [
  { pattern: /\bgit\s+commit\b/, replacement: "but commit <branch> -m 'message' --changes <id>" },
  { pattern: /\bgit\s+checkout\b/, replacement: "but apply/unapply or but branch new" },
  { pattern: /\bgit\s+switch\b/, replacement: "but apply/unapply" },
  { pattern: /\bgit\s+rebase\b/, replacement: "but squash, but move, or but rub" },
  { pattern: /\bgit\s+merge\b/, replacement: "but merge <branch>" },
  { pattern: /\bgit\s+reset\b/, replacement: "but undo or but oplog restore" },
  { pattern: /\bgit\s+revert\b/, replacement: "but undo" },
  { pattern: /\bgit\s+cherry-pick\b/, replacement: "but pick <source> [target]" },
  { pattern: /\bgit\s+stash\b/, replacement: "but unapply (to set aside work)" },
  { pattern: /\bgit\s+add\b/, replacement: "but stage <file> <branch>" },
  { pattern: /\bgit\s+restore\b/, replacement: "but discard <id>" },
];

function getGitRoot(): string | null {
  try {
    return execSync("git rev-parse --show-toplevel", {
      stdio: "pipe",
      timeout: 3000,
    })
      .toString()
      .trim();
  } catch {
    return null;
  }
}

function isGitButlerWorkspace(gitRoot: string): boolean {
  return existsSync(`${gitRoot}/.git/gitbutler`);
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return undefined;

    const command = event.input.command;

    // Find which blocked command matches
    const match = BLOCKED_COMMANDS.find((c) => c.pattern.test(command));
    if (!match) return undefined;

    // Only block in GitButler workspaces
    const gitRoot = getGitRoot();
    if (!gitRoot || !isGitButlerWorkspace(gitRoot)) return undefined;

    return {
      block: true,
      reason:
        `GitButler workspace detected — use \`but\` instead of git write commands.\n` +
        `Blocked: ${match.pattern.source.replace(/\\b|\\s\+/g, " ").trim()}\n` +
        `Use instead: ${match.replacement}`,
    };
  });

  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;

    const gitRoot = getGitRoot();
    if (gitRoot && isGitButlerWorkspace(gitRoot)) {
      ctx.ui.notify(
        "🧈 GitButler workspace — git write commands blocked, use `but` instead",
        "info"
      );
    }
  });
}
