// Pi extension: inject agentmap codebase tree into system prompt at session start.

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { generateMapYaml } from "agentmap";

const MAX_LINES = 1000;

export default function (pi: ExtensionAPI) {
  let cachedYaml: string | undefined;

  // Invalidate cache on session switch
  pi.on("session_start", async () => {
    cachedYaml = undefined;
  });

  pi.on("before_agent_start", async (event: any, ctx: any) => {
    try {
      if (!cachedYaml) {
        let yaml: string = await generateMapYaml({ dir: ctx.cwd, diff: true });

        const lines = yaml.split("\n");
        if (lines.length > MAX_LINES) {
          yaml = lines.slice(0, MAX_LINES).join("\n") + "\n# ... truncated";
        }

        cachedYaml = yaml;
      }

      if (!cachedYaml?.trim()) return;

      return {
        systemPrompt:
          event.systemPrompt +
          `

<agentmap>
Tree of the most important files in the repo, showing descriptions and definitions:

${cachedYaml}
</agentmap>

<agentmap-instructions>
When creating new files, add a brief description comment at the top explaining the file's purpose. This makes the file discoverable in the agentmap.

When making significant changes to a file's purpose or responsibilities, update its header comment to reflect the changes.

These descriptions appear in the agentmap XML at the start of every agent session.
</agentmap-instructions>`,
      };
    } catch (err) {
      console.error("[agentmap] Failed to generate map:", err);
    }
  });
}
