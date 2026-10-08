import { describe, expect, test } from "bun:test";

import { createLazyPlannotator } from "./lazy-plannotator";

function createExtensionApi() {
  const commands = new Map<string, { handler: (...args: unknown[]) => unknown }>();
  const flags = new Map<string, unknown>();
  const handlers = new Map<string, Array<(...args: unknown[]) => unknown>>();
  const shortcuts = new Map<string, { handler: (...args: unknown[]) => unknown }>();
  const tools = new Map<
    string,
    { execute: (...args: unknown[]) => unknown; renderCall?: (...args: unknown[]) => unknown }
  >();
  const flagValues = new Map<string, unknown>();

  return {
    commands,
    flags,
    flagValues,
    handlers,
    shortcuts,
    tools,
    api: {
      getFlag(name: string) {
        return flagValues.get(name);
      },
      on(event: string, handler: (...args: unknown[]) => unknown) {
        const eventHandlers = handlers.get(event) ?? [];
        eventHandlers.push(handler);
        handlers.set(event, eventHandlers);
      },
      registerCommand(name: string, options: { handler: (...args: unknown[]) => unknown }) {
        commands.set(name, options);
      },
      registerFlag(name: string, options: unknown) {
        flags.set(name, options);
      },
      registerShortcut(name: string, options: { handler: (...args: unknown[]) => unknown }) {
        shortcuts.set(name, options);
      },
      registerTool(tool: {
        name: string;
        execute: (...args: unknown[]) => unknown;
        renderCall?: (...args: unknown[]) => unknown;
      }) {
        tools.set(tool.name, tool);
      },
    },
  };
}

describe("plain Pi lazy Plannotator", () => {
  test("exposes the public surface without importing, then loads once on first use", async () => {
    const extension = createExtensionApi();
    const calls: unknown[][] = [];
    let imports = 0;
    const factory = createLazyPlannotator(async () => {
      imports += 1;
      return {
        default(pi: typeof extension.api) {
          pi.on("session_start", async (event: unknown, ctx: { cwd: string }) => {
            calls.push(["session_start", event, ctx.cwd]);
          });
          pi.registerFlag("plan", { type: "boolean" });
          pi.registerCommand("plannotator-review", {
            async handler(args: unknown, ctx: { cwd: string }) {
              calls.push(["review", args, ctx.cwd]);
            },
          });
          pi.registerShortcut("ctrl+alt+p", {
            async handler(ctx: { cwd: string }) {
              calls.push(["shortcut", ctx.cwd]);
            },
          });
          pi.registerTool({
            name: "plannotator_submit_plan",
            async execute(_id: unknown, params: unknown) {
              calls.push(["submit", params]);
              return { content: [{ type: "text", text: "submitted" }] };
            },
          });
        },
      };
    });

    await factory(extension.api);

    expect(imports).toBe(0);
    expect(extension.flags.has("plan")).toBe(true);
    expect(extension.commands.has("plannotator-review")).toBe(true);
    expect(extension.shortcuts.has("ctrl+alt+p")).toBe(true);
    expect(extension.tools.has("plannotator_submit_plan")).toBe(true);

    const context = { cwd: "/tmp/project" };
    await extension.handlers.get("session_start")?.[0]?.({ type: "session_start" }, context);
    expect(imports).toBe(0);

    await extension.commands.get("plannotator-review")?.handler("--git", context);
    await extension.commands.get("plannotator-review")?.handler("--git", context);
    const result = await extension.tools
      .get("plannotator_submit_plan")
      ?.execute("tool-1", { filePath: "PLAN.md" });

    expect(imports).toBe(1);
    expect(calls).toEqual([
      ["session_start", { type: "session_start", reason: "reload" }, "/tmp/project"],
      ["review", "--git", "/tmp/project"],
      ["review", "--git", "/tmp/project"],
      ["submit", { filePath: "PLAN.md" }],
    ]);
    expect(result?.content[0]?.text).toBe("submitted");
  });

  test("loads during session start when the plan flag is set", async () => {
    const extension = createExtensionApi();
    extension.flagValues.set("plan", true);
    let imports = 0;
    const factory = createLazyPlannotator(async () => {
      imports += 1;
      return { default() {} };
    });

    await factory(extension.api);
    await extension.handlers.get("session_start")?.[0]?.(
      { type: "session_start" },
      { cwd: "/tmp/project" }
    );

    expect(imports).toBe(1);
  });
});
