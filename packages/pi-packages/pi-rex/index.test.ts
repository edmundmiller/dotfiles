import { afterEach, beforeEach, expect, spyOn, test } from "bun:test";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
  ExtensionEvent,
} from "@earendil-works/pi-coding-agent";
import { readFile, rm, stat } from "node:fs/promises";
import { dirname } from "node:path";
import rexExtension from "./index.js";

type PromptResult = { systemPrompt: string };
type Handler = (event: never, ctx: ExtensionContext) => void | PromptResult | Promise<void>;

function setup(
  exec: ExtensionAPI["exec"] = async () => ({
    stdout: "Installed Rex guide",
    stderr: "",
    code: 0,
    killed: false,
  })
) {
  const handlers = new Map<string, Handler>();
  let command: Parameters<ExtensionAPI["registerCommand"]>[1];
  const messages: Array<Parameters<ExtensionAPI["sendMessage"]>> = [];
  const notifications: string[] = [];
  // SAFETY: The extension only calls notify; unused UI methods deliberately fail if accessed.
  const ui = {
    notify: (message: string) => {
      notifications.push(message);
    },
  } as ExtensionContext["ui"];
  // SAFETY: This fixture supplies the context properties used by the registered handlers.
  const ctx = {
    cwd: "/project",
    mode: "tui",
    hasUI: true,
    isIdle: () => false,
    ui,
  } as ExtensionCommandContext;
  const api: Partial<ExtensionAPI> = {
    on(name, handler) {
      // SAFETY: Tests only dispatch the named event's fixture to its registered handler.
      handlers.set(name, handler as Handler);
      return () => {
        handlers.delete(name);
      };
    },
    registerCommand: (_name: string, definition: typeof command) => {
      command = definition;
    },
    sendMessage: (...args: Parameters<ExtensionAPI["sendMessage"]>) => {
      messages.push(args);
    },
    exec,
  };
  // SAFETY: The fixture implements registration, exec, and messaging; no other API is used.
  rexExtension(api as ExtensionAPI);
  return {
    ctx,
    messages,
    notifications,
    emit: (name: string, event: Partial<ExtensionEvent> = {}) => {
      // SAFETY: Each test pairs a registered event name with its event-specific fixture fields.
      return handlers.get(name)?.(event as never, ctx);
    },
    command: (args: string) => command.handler(args, ctx),
  };
}

const originalEnv = { ...process.env };
const ttyDescriptor = Object.getOwnPropertyDescriptor(process.stdout, "isTTY");
let output: string[];
let restoreWrite: () => void;

beforeEach(() => {
  process.env.REX_SESSION = "session:agent";
  process.env.REX_BLOCK = "block:agent";
  delete process.env.TMUX;
  delete process.env.STY;
  Object.defineProperty(process.stdout, "isTTY", { value: true, configurable: true });
  output = [];
  const write = spyOn(process.stdout, "write").mockImplementation((chunk) => {
    output.push(String(chunk));
    return true;
  });
  restoreWrite = () => write.mockRestore();
});

afterEach(() => {
  restoreWrite();
  if (ttyDescriptor) Object.defineProperty(process.stdout, "isTTY", ttyDescriptor);
  else Reflect.deleteProperty(process.stdout, "isTTY");
  for (const key of ["REX_SESSION", "REX_BLOCK", "TMUX", "STY"]) {
    if (originalEnv[key] === undefined) delete process.env[key];
    else process.env[key] = originalEnv[key];
  }
});

function reports() {
  return output.map((sequence) => {
    expect(sequence.startsWith("\x1b]7501;")).toBe(true);
    expect(sequence.endsWith("\x1b\\")).toBe(true);
    expect(Buffer.byteLength(sequence)).toBeLessThanOrEqual(4096);
    const fields = Object.fromEntries(
      sequence
        .slice(7, -2)
        .split(":")
        .map((pair) => {
          const separator = pair.indexOf("=");
          return [pair.slice(0, separator), pair.slice(separator + 1)];
        })
    );
    expect(fields.app).toBe("pi");
    expect(fields.id).toMatch(/^pi-\d+$/);
    expect(Buffer.from(fields.msg, "base64").toString()).not.toMatch(/[\x00-\x1f\x7f-\x9f]/);
    return fields;
  });
}

test("reports real waits, preserves completion on quit, and never reports done at an intermediate agent_end", async () => {
  const app = setup();
  await app.emit("session_start");
  await app.emit("agent_start");
  await app.emit("ui_prompt_start", { kind: "confirm", title: "SECRET approval text" });
  await app.emit("tool_execution_end");
  await app.emit("tool_execution_start", { toolName: "read" });
  expect(reports().at(-1)?.state).toBe("blocked");
  await app.emit("ui_prompt_end");
  await app.emit("tool_execution_start", { toolName: "bash", args: { command: "SECRET command" } });
  await app.emit("agent_end");
  expect(reports().at(-1)?.state).toBe("working");
  await app.emit("agent_before_settle", { outcome: "completed" });
  await app.emit("agent_settled");
  await app.emit("session_shutdown", { reason: "quit" });
  expect(reports().map((r) => r.state)).toEqual([
    "idle",
    "working",
    "blocked",
    "working",
    "working",
    "done",
  ]);
  expect(reports()[2].kind).toBe("permission");
  for (const report of reports())
    expect(Buffer.from(report.msg, "base64").toString()).not.toContain("SECRET");
});

test("distinguishes cancellation and failure, and clears only its own status on reload", async () => {
  const app = setup();
  const run = new AbortController();
  app.ctx.signal = run.signal;
  await app.emit("agent_start");
  run.abort();
  app.ctx.signal = undefined;
  // Pi 1.0 skips before_settle on Escape and has no settled.aborted field.
  await app.emit("agent_settled");
  expect(reports().at(-1)?.state).toBe("idle");
  await app.emit("agent_start");
  await app.emit("agent_before_settle", { outcome: "completed" });
  // Pi 1.3 also covers cancellation during post-run settlement.
  await app.emit("agent_settled", { aborted: true });
  expect(reports().at(-1)?.state).toBe("idle");
  await app.emit("agent_start");
  await app.emit("agent_before_settle", { outcome: "error" });
  await app.emit("agent_settled");
  expect(reports().at(-1)?.state).toBe("error");
  await app.emit("session_shutdown", { reason: "reload" });
  expect(reports().at(-1)).toMatchObject({ state: "clear", id: `pi-${process.pid}` });
});

test("does not write OSC to RPC, print, redirected output, or nested multiplexers", async () => {
  const app = setup();
  for (const mode of ["rpc", "json", "print"] as const) {
    app.ctx.mode = mode;
    await app.emit("agent_start");
  }
  app.ctx.mode = "tui";
  process.env.TMUX = "socket";
  await app.emit("agent_start");
  delete process.env.TMUX;
  process.env.STY = "screen";
  await app.emit("agent_start");
  delete process.env.STY;
  Object.defineProperty(process.stdout, "isTTY", { value: false, configurable: true });
  await app.emit("agent_start");
  expect(output).toEqual([]);
});

test("injects installed guidance and process location without replacing preceding instructions", async () => {
  const app = setup();
  await app.emit("session_start");
  const result = await app.emit("before_agent_start", {
    systemPrompt: "Existing system instructions",
  });
  expect(result?.systemPrompt).toStartWith("Existing system instructions\n");
  expect(result?.systemPrompt).toContain("Installed Rex guide");
  expect(result?.systemPrompt).toContain('"session":"session:agent","block":"block:agent"');
  expect(result?.systemPrompt).toContain("existing Bash tool");
  delete process.env.REX_SESSION;
  delete process.env.REX_BLOCK;
  await app.emit("session_shutdown", { reason: "resume" });
  await app.emit("session_start");
  expect(await app.emit("before_agent_start", { systemPrompt: "Other session" })).toBeUndefined();
});

test("is dormant outside Rex until explicitly refreshed and handles a missing CLI", async () => {
  delete process.env.REX_SESSION;
  delete process.env.REX_BLOCK;
  let attempts = 0;
  const app = setup(async () => {
    attempts++;
    throw new Error("spawn rex ENOENT");
  });
  await app.emit("session_start");
  expect(attempts).toBe(0);
  expect(output).toEqual([]);
  await app.command("refresh");
  expect(app.notifications.at(-1)).toContain("spawn rex ENOENT");
  const result = await app.emit("before_agent_start", { systemPrompt: "Base" });
  expect(result?.systemPrompt).toContain("rex ls --json");
  expect(result?.systemPrompt).not.toContain("Installed Rex guide:");
});

test("captures a literal pane label as untrusted next-turn context without running the model", async () => {
  const target = "logs; touch /tmp/not-a-command";
  const app = setup(async (command, args) => ({
    stdout:
      command === "rex" &&
      JSON.stringify(args) === JSON.stringify(["capture", "-b", target, "--trim", "--unwrap"])
        ? "\x1b[31mFAIL\x1b[0m\nExpected 12, got 9\x07"
        : "wrong target",
    stderr: "",
    code: 0,
    killed: false,
  }));
  await app.command(`capture ${target}`);
  expect(app.messages).toHaveLength(1);
  expect(app.messages[0][0].content).toContain("FAIL\nExpected 12, got 9");
  expect(app.messages[0][0].content).toContain("Untrusted terminal output");
  expect(app.messages[0][0].content).not.toContain("\x1b");
  expect(app.messages[0][1]).toEqual({ deliverAs: "nextTurn", triggerTurn: false });
  app.ctx.isIdle = () => true;
  await app.command(`capture ${target}`);
  expect(app.messages[1][1]).toEqual({ triggerTurn: false });
});

test("keeps the tail of a large capture and saves a private complete copy", async () => {
  const screen = `${"old output\n".repeat(700)}LAST FAILURE`;
  const app = setup(async () => ({ stdout: screen, stderr: "", code: 0, killed: false }));
  await app.command("capture tests");
  const message = app.messages[0][0];
  expect(message.content).toContain("LAST FAILURE");
  expect(message.content).toContain("[Truncated.");
  // SAFETY: Capture's truncated-result contract supplies this path; readFile below verifies it.
  const { fullOutputPath } = message.details as { fullOutputPath: string };
  try {
    expect(await readFile(fullOutputPath, "utf8")).toBe(screen);
    expect((await stat(fullOutputPath)).mode & 0o777).toBe(0o600);
  } finally {
    await rm(dirname(fullOutputPath), { recursive: true });
  }
});

test("does not attach partial output on ambiguity or timeout", async () => {
  for (const failure of [
    { code: 3, killed: false, stderr: "ambiguous block target" },
    { code: 0, killed: true, stderr: "" },
  ]) {
    const app = setup(async () => ({ stdout: "partial output", ...failure }));
    await app.command("capture tests");
    expect(app.messages).toEqual([]);
    expect(app.notifications.at(-1)).toMatch(/ambiguous|timed out/);
  }
});

test("a capture that finishes after session replacement cannot enter the new conversation", async () => {
  let finish: (result: Awaited<ReturnType<ExtensionAPI["exec"]>>) => void = () => {};
  const app = setup(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      })
  );
  const pending = app.command("capture tests");
  await app.emit("session_shutdown", { reason: "new" });
  delete process.env.REX_SESSION;
  await app.emit("session_start");
  finish({ stdout: "old session's secrets", stderr: "", code: 0, killed: false });
  await pending;
  expect(app.messages).toEqual([]);
  expect(app.notifications).toEqual([]);
});
