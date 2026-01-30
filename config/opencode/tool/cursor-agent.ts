// Cursor Agent tool - calls the external cursor-agent CLI for deep research
import { tool } from "@opencode-ai/plugin";

/**
 * Call cursor-agent CLI for deep research, second opinions, or bug fixing help
 */
export const ask = tool({
  description:
    "Call the cursor-agent CLI for deep research, a second opinion, or help fixing a bug. " +
    "Pass all relevant context including your current findings and the problem you're trying to solve. " +
    "This spawns an external AI agent (GPT-5/Cursor) that can provide a different perspective.",
  args: {
    prompt: tool.schema
      .string()
      .describe("The task and context to pass to cursor-agent. Include all relevant details."),
  },
  async execute(args) {
    try {
      const result = await Bun.$`cursor-agent -p ${args.prompt}`.text();
      return `## Cursor Agent Response\n\n${result.trim()}`;
    } catch (error: any) {
      if (error.exitCode) {
        return `Cursor agent failed (exit code ${error.exitCode}):\n${error.stderr || error.message}`;
      }
      return `Error calling cursor-agent: ${error.message}`;
    }
  },
});
