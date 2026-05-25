/**
 * non-interactive-env extension.
 *
 * Replaces bash with a non-interactive wrapper and blocks known interactive
 * commands that commonly hang in agent tool runs.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { createBashTool, isToolCallEventType } from "@mariozechner/pi-coding-agent";
import { NON_INTERACTIVE_ENV, shouldBlockInteractiveCommand } from "./command-guard";

export default function (pi: ExtensionAPI) {
  const cwd = process.cwd();

  const bashTool = createBashTool(cwd, {
    spawnHook: ({ command, cwd, env }) => ({
      command,
      cwd,
      env: {
        ...env,
        ...NON_INTERACTIVE_ENV,
      },
    }),
  });

  pi.on("tool_call", async (event) => {
    if (!isToolCallEventType("bash", event)) return undefined;
    return shouldBlockInteractiveCommand(event.input.command);
  });

  pi.registerTool({
    ...bashTool,
    execute: async (id, params, signal, onUpdate, _ctx) => {
      return bashTool.execute(id, params, signal, onUpdate);
    },
  });
}
