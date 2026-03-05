import { describe, expect, mock, test, beforeEach } from "bun:test";

// Mock agentmap before importing extension
const generateMapYaml = mock(async () => "src/:\n  index.ts:\n    desc: entry");
mock.module("agentmap", () => ({ generateMapYaml }));

// Now import the extension (picks up mocked agentmap)
const { default: registerExtension } = await import("../index");

type Handler = (event: any, ctx: any) => Promise<any>;

function mockPi() {
  const handlers: Record<string, Handler[]> = {};
  return {
    on(event: string, handler: Handler) {
      (handlers[event] ??= []).push(handler);
    },
    _fire: async (event: string, arg0?: any, arg1?: any) => {
      for (const h of handlers[event] ?? []) {
        const result = await h(arg0, arg1);
        if (result) return result;
      }
    },
    _handlers: handlers,
  };
}

describe("extension registration", () => {
  test("registers before_agent_start and session_start handlers", () => {
    const pi = mockPi();
    registerExtension(pi as any);
    expect(pi._handlers["before_agent_start"]).toHaveLength(1);
    expect(pi._handlers["session_start"]).toHaveLength(1);
  });
});

describe("before_agent_start", () => {
  let pi: ReturnType<typeof mockPi>;

  beforeEach(() => {
    pi = mockPi();
    generateMapYaml.mockClear();
    generateMapYaml.mockImplementation(async () => "src/:\n  index.ts:\n    desc: entry");
    registerExtension(pi as any);
  });

  test("injects agentmap into system prompt", async () => {
    const result = await pi._fire("before_agent_start", { systemPrompt: "base" }, { cwd: "/app" });

    expect(result).toBeDefined();
    expect(result.systemPrompt).toStartWith("base");
    expect(result.systemPrompt).toContain("<agentmap>");
    expect(result.systemPrompt).toContain("src/:\n  index.ts:\n    desc: entry");
  });

  test("passes cwd and diff:true to generateMapYaml", async () => {
    await pi._fire("before_agent_start", { systemPrompt: "" }, { cwd: "/my/project" });

    expect(generateMapYaml).toHaveBeenCalledWith({ dir: "/my/project", diff: true });
  });

  test("caches yaml across calls", async () => {
    await pi._fire("before_agent_start", { systemPrompt: "" }, { cwd: "/app" });
    await pi._fire("before_agent_start", { systemPrompt: "" }, { cwd: "/app" });

    expect(generateMapYaml).toHaveBeenCalledTimes(1);
  });

  test("session_start invalidates cache", async () => {
    await pi._fire("before_agent_start", { systemPrompt: "" }, { cwd: "/app" });
    await pi._fire("session_start");
    await pi._fire("before_agent_start", { systemPrompt: "" }, { cwd: "/app" });

    expect(generateMapYaml).toHaveBeenCalledTimes(2);
  });

  test("returns undefined for empty yaml", async () => {
    generateMapYaml.mockImplementation(async () => "");

    const result = await pi._fire("before_agent_start", { systemPrompt: "base" }, { cwd: "/app" });

    expect(result).toBeUndefined();
  });

  test("returns undefined for whitespace-only yaml", async () => {
    generateMapYaml.mockImplementation(async () => "   \n  \n  ");

    const result = await pi._fire("before_agent_start", { systemPrompt: "base" }, { cwd: "/app" });

    expect(result).toBeUndefined();
  });

  test("swallows errors and returns undefined", async () => {
    generateMapYaml.mockImplementation(async () => {
      throw new Error("tree-sitter exploded");
    });

    const result = await pi._fire("before_agent_start", { systemPrompt: "base" }, { cwd: "/app" });

    expect(result).toBeUndefined();
  });

  test("truncates large yaml", async () => {
    const bigYaml = Array.from({ length: 1500 }, (_, i) => `line-${i}`).join("\n");
    generateMapYaml.mockImplementation(async () => bigYaml);

    const result = await pi._fire("before_agent_start", { systemPrompt: "" }, { cwd: "/app" });

    expect(result.systemPrompt).toContain("# ... truncated");
    expect(result.systemPrompt).not.toContain("line-1499");
  });
});
