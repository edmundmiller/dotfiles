/**
 * gitbutler-guard — pure logic (no Pi SDK dependency)
 *
 * Extracted so tests can run without @mariozechner/pi-coding-agent.
 */

import { existsSync } from "node:fs";
import { execSync } from "node:child_process";

// Git write commands that should use `but` equivalents
export const BLOCKED_COMMANDS: { pattern: RegExp; replacement: string }[] = [
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

/**
 * Find which blocked command matches a bash command string.
 */
export function findBlockedCommand(command: string) {
  return BLOCKED_COMMANDS.find((c) => c.pattern.test(command));
}

/**
 * Check if a directory is a GitButler workspace.
 */
export function isGitButlerWorkspace(gitRoot: string): boolean {
  return existsSync(`${gitRoot}/.git/gitbutler`);
}

/**
 * Get the git repository root for the current directory.
 */
export function getGitRoot(): string | null {
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

/**
 * Determine if a command should be blocked in a GitButler workspace.
 */
export function shouldBlock(
  command: string,
  gitRoot: string | null,
  isButlerWorkspace: (root: string) => boolean = isGitButlerWorkspace
) {
  const match = findBlockedCommand(command);
  if (!match) return undefined;

  if (!gitRoot || !isButlerWorkspace(gitRoot)) return undefined;

  return {
    block: true as const,
    reason:
      `GitButler workspace detected — use \`but\` instead of git write commands.\n` +
      `Blocked: ${match.pattern.source.replace(/\\b|\\s\+/g, " ").trim()}\n` +
      `Use instead: ${match.replacement}`,
  };
}
