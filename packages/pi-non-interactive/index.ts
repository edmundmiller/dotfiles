/**
 * non-interactive-env Extension
 *
 * Prevents pi from hanging on commands that open interactive editors or pagers.
 * Sets env vars that make git/tools fail gracefully instead of blocking.
 *
 * Covered:
 * - GIT_EDITOR=true           → git rebase --continue, git commit (no -m), etc.
 * - GIT_SEQUENCE_EDITOR=true  → git rebase -i sequence editing
 * - GIT_PAGER=cat             → git log, git diff, git show (no pager hang)
 * - PAGER=cat                 → any tool that respects $PAGER
 * - LESS=-FX                  → less exits immediately if output fits one screen
 * - BAT_PAGER=cat             → bat (syntax highlighter) non-interactive
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { createBashTool } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  const cwd = process.cwd();

  const bashTool = createBashTool(cwd, {
    spawnHook: ({ command, cwd, env }) => ({
      command,
      cwd,
      env: {
        ...env,
        GIT_EDITOR: "true",
        GIT_SEQUENCE_EDITOR: "true",
        GIT_PAGER: "cat",
        PAGER: "cat",
        LESS: "-FX",
        BAT_PAGER: "cat",
      },
    }),
  });

  pi.registerTool({
    ...bashTool,
    execute: async (id, params, signal, onUpdate, _ctx) => {
      return bashTool.execute(id, params, signal, onUpdate);
    },
  });
}
