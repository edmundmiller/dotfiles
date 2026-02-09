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
import { getGitRoot, isGitButlerWorkspace, shouldBlock } from "./gitbutler-guard-logic";

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, _ctx) => {
    if (!isToolCallEventType("bash", event)) return undefined;
    return shouldBlock(event.input.command, getGitRoot());
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
