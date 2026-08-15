import { describe, expect, test } from "bun:test";

import { createLazyAgentBrowser } from "../config/omp/extensions/lazy-agent-browser.mjs";
import { createLazyPlannotator } from "../config/omp/extensions/lazy-plannotator.mjs";

function createExtensionApi() {
  const commands = new Map();
  const handlers = new Map();
  const tools = new Map();

  return {
    commands,
    handlers,
    tools,
    api: {
      on(event, handler) {
        const eventHandlers = handlers.get(event) ?? [];
        eventHandlers.push(handler);
        handlers.set(event, eventHandlers);
      },
      registerCommand(name, options) {
        commands.set(name, options);
      },
      registerTool(tool) {
        tools.set(tool.name, tool);
      },
    },
  };
}

describe("lazy Plannotator", () => {
  test("loads once on the first existing command and replays session start", async () => {
    const extension = createExtensionApi();
    const calls = [];
    let imports = 0;
    const factory = createLazyPlannotator(async () => {
      imports += 1;
      return {
        default(pi) {
          pi.on("session_start", async (event, ctx) => {
            calls.push(["session_start", event.reason, ctx.cwd]);
          });
          pi.registerCommand("plannotator-review", {
            description: "real review command",
            async handler(args, ctx) {
              calls.push(["review", args, ctx.cwd]);
            },
          });
        },
      };
    });

    await factory(extension.api);

    expect(imports).toBe(0);
    expect(extension.commands.has("plannotator-review")).toBe(true);

    const context = { cwd: "/tmp/project" };
    await extension.commands.get("plannotator-review").handler("--git", context);
    await extension.commands.get("plannotator-review").handler("--git", context);

    expect(imports).toBe(1);
    expect(calls).toEqual([
      ["session_start", "reload", "/tmp/project"],
      ["review", "--git", "/tmp/project"],
      ["review", "--git", "/tmp/project"],
    ]);
  });
});

describe("lazy agent browser", () => {
  test("loads on browser intent, forwards lifecycle, and delegates the native tool", async () => {
    const extension = createExtensionApi();
    const calls = [];
    let imports = 0;
    const factory = createLazyAgentBrowser({
      async importExtension() {
        imports += 1;
        return {
          default(pi) {
            pi.on("session_start", async (event, ctx) => {
              calls.push(["session_start", event.reason, ctx.cwd]);
            });
            pi.on("before_agent_start", async (event) => ({
              systemPrompt: `${event.systemPrompt}\nreal browser guidance`,
            }));
            pi.registerTool({
              name: "agent_browser",
              async execute(_toolCallId, params) {
                calls.push(["execute", params.args]);
                return { content: [{ type: "text", text: "browser ok" }] };
              },
            });
          },
        };
      },
      async loadSurface() {
        return {
          parameters: { type: "object" },
          promptGuidelines: ["browser guideline"],
          shouldActivateForPrompt(prompt) {
            return prompt.includes("browser");
          },
        };
      },
    });

    await factory(extension.api);

    expect(imports).toBe(0);
    expect(extension.tools.has("agent_browser")).toBe(true);

    const beforeAgentStart = extension.handlers.get("before_agent_start")[0];
    const context = { cwd: "/tmp/project" };
    expect(
      await beforeAgentStart({ prompt: "read the code", systemPrompt: "base" }, context)
    ).toBeUndefined();
    expect(imports).toBe(0);

    expect(
      await beforeAgentStart({ prompt: "open this in the browser", systemPrompt: "base" }, context)
    ).toEqual({ systemPrompt: "base\nreal browser guidance" });

    const result = await extension.tools
      .get("agent_browser")
      .execute("tool-1", { args: ["open", "https://example.com"] });

    expect(imports).toBe(1);
    expect(calls).toEqual([
      ["session_start", "reload", "/tmp/project"],
      ["execute", ["open", "https://example.com"]],
    ]);
    expect(result.content[0].text).toBe("browser ok");
  });
});
