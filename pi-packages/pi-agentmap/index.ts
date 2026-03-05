// Pi extension: inject agentmap codebase tree into system prompt at session start.

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { generateMapYaml } from "agentmap";
import { buildSystemPrompt, truncateYaml } from "./src/core";

export default function (pi: ExtensionAPI) {
  let cachedYaml: string | undefined;

  // Invalidate cache on session switch
  pi.on("session_start", async () => {
    cachedYaml = undefined;
  });

  pi.on("before_agent_start", async (event: any, ctx: any) => {
    try {
      if (!cachedYaml) {
        const yaml = await generateMapYaml({ dir: ctx.cwd, diff: true });
        cachedYaml = truncateYaml(yaml);
      }

      if (!cachedYaml?.trim()) return;

      return { systemPrompt: buildSystemPrompt(event.systemPrompt, cachedYaml) };
    } catch (err) {
      console.error("[agentmap] Failed to generate map:", err);
    }
  });
}
