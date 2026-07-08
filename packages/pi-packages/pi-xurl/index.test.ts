import { describe, expect, mock, test } from "bun:test";

mock.module("@mariozechner/pi-coding-agent", () => ({
  DEFAULT_MAX_BYTES: 1_000_000,
  DEFAULT_MAX_LINES: 10_000,
  formatSize: (bytes: number) => `${bytes} B`,
  truncateHead: (content: string) => ({
    content,
    truncated: false,
    outputLines: content.split("\n").length,
    totalLines: content.split("\n").length,
    outputBytes: new TextEncoder().encode(content).byteLength,
    totalBytes: new TextEncoder().encode(content).byteLength,
  }),
}));

mock.module("@sinclair/typebox", () => ({
  Type: {
    Object: (schema: unknown) => schema,
    String: (options?: Record<string, unknown>) => ({ type: "string", ...options }),
    Optional: (schema: unknown) => schema,
    Boolean: (options?: Record<string, unknown>) => ({ type: "boolean", ...options }),
  },
}));
// Dynamic import lets Bun install the mocked Pi peer dependency before the extension loads.
const xurlModule = await import("./index.ts");

type ToolParams = {
  uri: string;
  raw?: boolean;
  list?: boolean;
};

type ToolResult = {
  content: Array<{ type: "text"; text: string }>;
  details: Record<string, unknown>;
  isError?: boolean;
};

type RegisteredTool = {
  name: string;
  execute: (id: string, params: ToolParams, signal?: AbortSignal) => Promise<ToolResult>;
};

type PiMock = {
  registerTool: (tool: RegisteredTool) => void;
  registerCommand: (name: string, command: unknown) => void;
  exec: (
    command: string,
    args: string[],
    options?: Record<string, unknown>
  ) => Promise<{ code: number; stdout: string; stderr: string }>;
};

const xurlExtension: (pi: PiMock) => void = xurlModule.default;

type ExecCall = {
  command: string;
  args: string[];
  options: Record<string, unknown>;
};

function createPiMock() {
  const calls: ExecCall[] = [];
  const tools: Record<string, RegisteredTool | undefined> = {};

  const pi = {
    registerTool(tool: RegisteredTool) {
      tools[tool.name] = tool;
    },
    registerCommand(_name: string, _command: unknown) {},
    async exec(command: string, args: string[], options: Record<string, unknown> = {}) {
      calls.push({ command, args, options });
      return { code: 0, stdout: `${command} ${args.join(" ")}\n`, stderr: "" };
    },
  };

  xurlExtension(pi);

  const tool = tools.xurl;
  if (!tool) throw new Error("xurl tool was not registered");

  return { calls, tool };
}

async function execute(uri: string, params: Omit<ToolParams, "uri"> = {}) {
  const mock = createPiMock();
  const result = await mock.tool.execute("tc-1", { uri, ...params });
  return { ...mock, result };
}

function expectRoute(
  result: ToolResult,
  calls: ExecCall[],
  uri: string,
  command: string,
  args: string[]
) {
  expect(calls.map((call) => [call.command, call.args])).toEqual([[command, args]]);
  expect(result).toMatchObject({
    content: [{ type: "text", text: `${command} ${args.join(" ")}\n` }],
    details: { uri, truncated: false },
  });
}

describe("pi-xurl", () => {
  test("routes herdr snapshot URIs to herdr api snapshot", async () => {
    const uri = "herdr://snapshot";
    const { calls, result } = await execute(uri);

    expectRoute(result, calls, uri, "herdr", ["api", "snapshot", "--json"]);
  });

  test("routes herdr pane reads with query options to herdr pane read", async () => {
    const uri = "herdr://pane/w1-2?source=visible&lines=120";
    const { calls, result } = await execute(uri);

    expectRoute(result, calls, uri, "herdr", [
      "pane",
      "read",
      "w1-2",
      "--source",
      "visible",
      "--lines",
      "120",
    ]);
  });

  test("routes hunk review URIs to hunk session review with include flags", async () => {
    const uri = "hunk://review?repo=/tmp/repo&includePatch=1&includeNotes=1";
    const { calls, result } = await execute(uri);

    expectRoute(result, calls, uri, "hunk", [
      "session",
      "review",
      "--repo",
      "/tmp/repo",
      "--include-patch",
      "--include-notes",
    ]);
  });

  test("routes hunk comment list URIs to hunk session comment list", async () => {
    const uri = "hunk://comments?repo=/tmp/repo&type=user";
    const { calls, result } = await execute(uri);

    expectRoute(result, calls, uri, "hunk", [
      "session",
      "comment",
      "list",
      "--repo",
      "/tmp/repo",
      "--type",
      "user",
    ]);
  });

  test("falls back to xurl for agent URIs and forwards raw/list flags", async () => {
    const uri = "agents://pi/turn-1";
    const { calls, result } = await execute(uri, { raw: true, list: true });
    const args = ["@xuanwo/xurl", uri, "--raw", "--list"];

    expectRoute(result, calls, uri, "npx", args);
    expect(result.details).toMatchObject({ raw: true, list: true });
  });
});
