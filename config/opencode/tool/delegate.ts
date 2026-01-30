// Delegate tool for Boomerang orchestration pattern
// Spawns child sessions to run tasks in parallel subagents
import { tool } from "@opencode-ai/plugin";
import { createOpencodeClient } from "@opencode-ai/sdk";

// Create a client that connects to the running opencode instance
const getClient = () => createOpencodeClient({ baseUrl: "http://localhost:4096" });

/**
 * Delegate a single task to a subagent, creating a child session
 */
export const task = tool({
  description:
    "Delegate a task to a subagent in a new child session. " +
    "The subagent works independently and returns its result. " +
    "Use for complex subtasks that benefit from focused attention. " +
    "Child sessions are navigable with ctrl+right/ctrl+left.",
  args: {
    title: tool.schema.string().describe("Short title for the child session (shown in UI)"),
    prompt: tool.schema.string().describe("Detailed task prompt with all necessary context"),
    agent: tool.schema
      .string()
      .optional()
      .describe(
        "Agent to use: 'coder', 'explore', 'general', or custom agent name. Defaults to 'coder'"
      ),
    wait: tool.schema
      .boolean()
      .optional()
      .describe(
        "Wait for completion and return result (default: true). Set false for fire-and-forget."
      ),
  },
  async execute(args, ctx) {
    const client = getClient();
    const agentName = args.agent || "coder";
    const shouldWait = args.wait !== false;

    try {
      // Create a child session linked to the current session
      const { data: session } = await client.session.create({
        body: {
          title: args.title,
          parentID: ctx.sessionID,
        },
      });

      if (!session) {
        return "Error: Failed to create child session";
      }

      // Send the prompt to the child session with the specified agent
      const { data: result } = await client.session.prompt({
        path: { id: session.id },
        body: {
          parts: [
            {
              type: "text",
              text: `@${agentName} ${args.prompt}`,
            },
          ],
        },
      });

      if (!shouldWait) {
        return `Spawned child session "${args.title}" (${session.id}) with @${agentName}. Navigate with ctrl+right.`;
      }

      // Wait for the session to become idle (task complete)
      let attempts = 0;
      const maxAttempts = 300; // 5 minutes max wait (1s intervals)

      while (attempts < maxAttempts) {
        await new Promise((resolve) => setTimeout(resolve, 1000));
        attempts++;

        const { data: status } = await client.session.get({
          path: { id: session.id },
        });

        if (status?.status === "idle") {
          // Get the final messages to extract the result
          const { data: messages } = await client.session.messages({
            path: { id: session.id },
          });

          if (messages && messages.length > 0) {
            // Find the last assistant message
            const lastAssistant = messages.reverse().find((m: any) => m.info?.role === "assistant");

            if (lastAssistant?.parts) {
              const textParts = lastAssistant.parts
                .filter((p: any) => p.type === "text")
                .map((p: any) => p.text)
                .join("\n");

              return `## Result from "${args.title}" (@${agentName})\n\n${textParts}`;
            }
          }

          return `Child session "${args.title}" completed but no text response found.`;
        }

        if (status?.status === "error") {
          return `Child session "${args.title}" encountered an error.`;
        }
      }

      return `Child session "${args.title}" timed out after 5 minutes. Check child session for status.`;
    } catch (error: any) {
      return `Error delegating task: ${error.message}`;
    }
  },
});

/**
 * Delegate multiple tasks in parallel, wait for all to complete
 */
export const parallel = tool({
  description:
    "Delegate multiple tasks to run in parallel child sessions. " +
    "All tasks start simultaneously and results are collected when all complete. " +
    "Ideal for independent subtasks that don't depend on each other.",
  args: {
    tasks: tool.schema
      .array(
        tool.schema.object({
          title: tool.schema.string().describe("Short title for this task"),
          prompt: tool.schema.string().describe("Task prompt"),
          agent: tool.schema.string().optional().describe("Agent to use (default: coder)"),
        })
      )
      .describe("Array of tasks to run in parallel"),
  },
  async execute(args, ctx) {
    const client = getClient();
    const results: { title: string; result: string; status: "success" | "error" | "timeout" }[] =
      [];

    try {
      // Spawn all child sessions simultaneously
      const sessions = await Promise.all(
        args.tasks.map(async (task) => {
          const { data: session } = await client.session.create({
            body: {
              title: task.title,
              parentID: ctx.sessionID,
            },
          });

          if (!session) {
            return { task, session: null, error: "Failed to create session" };
          }

          // Start the task
          await client.session.prompt({
            path: { id: session.id },
            body: {
              parts: [
                {
                  type: "text",
                  text: `@${task.agent || "coder"} ${task.prompt}`,
                },
              ],
            },
          });

          return { task, session, error: null };
        })
      );

      // Wait for all sessions to complete
      const maxWaitMs = 5 * 60 * 1000; // 5 minutes
      const startTime = Date.now();

      while (Date.now() - startTime < maxWaitMs) {
        const pendingSessions = sessions.filter(
          (s) => s.session && !results.find((r) => r.title === s.task.title)
        );

        if (pendingSessions.length === 0) break;

        await Promise.all(
          pendingSessions.map(async ({ task, session }) => {
            if (!session) return;

            const { data: status } = await client.session.get({
              path: { id: session.id },
            });

            if (status?.status === "idle") {
              const { data: messages } = await client.session.messages({
                path: { id: session.id },
              });

              let resultText = "No response";

              if (messages && messages.length > 0) {
                const lastAssistant = messages
                  .reverse()
                  .find((m: any) => m.info?.role === "assistant");

                if (lastAssistant?.parts) {
                  resultText = lastAssistant.parts
                    .filter((p: any) => p.type === "text")
                    .map((p: any) => p.text)
                    .join("\n");
                }
              }

              results.push({ title: task.title, result: resultText, status: "success" });
            } else if (status?.status === "error") {
              results.push({
                title: task.title,
                result: "Task encountered an error",
                status: "error",
              });
            }
          })
        );

        // Check if all done
        if (results.length === sessions.length) break;

        await new Promise((resolve) => setTimeout(resolve, 1000));
      }

      // Mark any remaining as timed out
      for (const { task } of sessions) {
        if (!results.find((r) => r.title === task.title)) {
          results.push({ title: task.title, result: "Timed out", status: "timeout" });
        }
      }

      // Format results
      const output = results
        .map((r) => `## ${r.title} [${r.status}]\n\n${r.result}`)
        .join("\n\n---\n\n");

      return `# Parallel Tasks Complete (${results.filter((r) => r.status === "success").length}/${results.length} succeeded)\n\n${output}`;
    } catch (error: any) {
      return `Error running parallel tasks: ${error.message}`;
    }
  },
});

/**
 * List active child sessions for the current session
 */
export const children = tool({
  description:
    "List all child sessions spawned from the current session. Shows their status and titles.",
  args: {},
  async execute(_args, ctx) {
    const client = getClient();

    try {
      const { data: childSessions } = await client.session.children({
        path: { id: ctx.sessionID },
      });

      if (!childSessions || childSessions.length === 0) {
        return "No child sessions found.";
      }

      const lines = childSessions.map(
        (s: any) => `- **${s.title || "Untitled"}** (${s.id}) - Status: ${s.status}`
      );

      return `# Child Sessions (${childSessions.length})\n\n${lines.join("\n")}`;
    } catch (error: any) {
      return `Error listing children: ${error.message}`;
    }
  },
});
