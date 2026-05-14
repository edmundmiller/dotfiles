import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

const HERDR_TIMEOUT_MS = 10_000;

const stringify = (value: unknown): string =>
  typeof value === "string" ? value : JSON.stringify(value, null, 2);

const textResult = (text: string, details: Record<string, unknown> = {}) => ({
  content: [{ type: "text" as const, text }],
  details,
});

const runHerdr = async (
  pi: ExtensionAPI,
  args: string[],
  options: { cwd?: string; timeout?: number } = {}
) => {
  const result = await pi.exec("herdr", args, {
    cwd: options.cwd ?? process.cwd(),
    timeout: options.timeout ?? HERDR_TIMEOUT_MS,
  });

  const stdout = result.stdout?.trim() ?? "";
  const stderr = result.stderr?.trim() ?? "";

  if (result.code !== 0) {
    throw new Error(
      [`herdr ${args.join(" ")} failed with exit code ${result.code}`, stdout, stderr]
        .filter(Boolean)
        .join("\n\n")
    );
  }

  return { stdout, stderr, code: result.code };
};

const parseJson = (text: string): unknown => {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
};

export default function herdrExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "herdr_status",
    label: "Herdr Status",
    description: "Check the local herdr client/server status and socket compatibility.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const result = await runHerdr(pi, ["status"]);
      return textResult(result.stdout || "herdr status returned no output", result);
    },
  });

  pi.registerTool({
    name: "herdr_list",
    label: "Herdr List",
    description: "List herdr workspaces, tabs, or panes using the running herdr server.",
    parameters: Type.Object({
      resource: Type.Union(
        [Type.Literal("workspaces"), Type.Literal("tabs"), Type.Literal("panes")],
        { description: "Which herdr resource to list." }
      ),
      workspaceId: Type.Optional(
        Type.String({ description: "Optional workspace id filter for tabs or panes." })
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const args =
        params.resource === "workspaces"
          ? ["workspace", "list"]
          : params.resource === "tabs"
            ? ["tab", "list"]
            : ["pane", "list"];

      if (params.workspaceId && params.resource !== "workspaces") {
        args.push("--workspace", params.workspaceId);
      }

      const result = await runHerdr(pi, args);
      const parsed = parseJson(result.stdout);
      return textResult(stringify(parsed), { ...result, parsed });
    },
  });

  pi.registerTool({
    name: "herdr_read_pane",
    label: "Herdr Read Pane",
    description: "Read visible or recent output from a herdr pane.",
    parameters: Type.Object({
      paneId: Type.String({ description: "Stable herdr pane id, e.g. w...-1 or positional 1-1." }),
      source: Type.Optional(
        Type.Union(
          [Type.Literal("visible"), Type.Literal("recent"), Type.Literal("recent-unwrapped")],
          { description: "Output source. Defaults to recent." }
        )
      ),
      lines: Type.Optional(
        Type.Number({ description: "Number of lines to read. Defaults to 80; herdr caps at 1000." })
      ),
      ansi: Type.Optional(Type.Boolean({ description: "Preserve ANSI formatting." })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const args = ["pane", "read", params.paneId, "--source", params.source ?? "recent"];
      if (params.lines) args.push("--lines", String(params.lines));
      if (params.ansi) args.push("--ansi");
      const result = await runHerdr(pi, args);
      return textResult(result.stdout || "(pane output empty)", result);
    },
  });

  pi.registerTool({
    name: "herdr_run_in_pane",
    label: "Herdr Run In Pane",
    description: "Send a command to a herdr pane and press Enter via `herdr pane run`.",
    parameters: Type.Object({
      paneId: Type.String({ description: "Target herdr pane id." }),
      command: Type.String({ description: "Command text to send to the pane." }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await runHerdr(pi, ["pane", "run", params.paneId, params.command]);
      return textResult("Command sent to herdr pane.", result);
    },
  });

  pi.registerTool({
    name: "herdr_wait",
    label: "Herdr Wait",
    description: "Wait for pane output to match text/regex or for an agent status transition.",
    parameters: Type.Object({
      kind: Type.Union([Type.Literal("output"), Type.Literal("agent-status")]),
      paneId: Type.String({ description: "Target herdr pane id." }),
      match: Type.Optional(
        Type.String({ description: "Text or regex to match when kind is output." })
      ),
      regex: Type.Optional(
        Type.Boolean({ description: "Treat match as a regex for output waits." })
      ),
      status: Type.Optional(
        Type.Union(
          [
            Type.Literal("idle"),
            Type.Literal("working"),
            Type.Literal("blocked"),
            Type.Literal("done"),
            Type.Literal("unknown"),
          ],
          { description: "Agent status when kind is agent-status." }
        )
      ),
      timeoutMs: Type.Optional(
        Type.Number({ description: "Timeout in milliseconds. Defaults to 60000." })
      ),
      lines: Type.Optional(Type.Number({ description: "Lines to scan for output waits." })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const timeout = String(params.timeoutMs ?? 60_000);
      const args = ["wait", params.kind, params.paneId];

      if (params.kind === "output") {
        if (!params.match) throw new Error("match is required for output waits");
        args.push("--match", params.match, "--timeout", timeout);
        if (params.regex) args.push("--regex");
        if (params.lines) args.push("--lines", String(params.lines));
      } else {
        if (!params.status) throw new Error("status is required for agent-status waits");
        args.push("--status", params.status, "--timeout", timeout);
      }

      const result = await runHerdr(pi, args, { timeout: Number(timeout) + 2_000 });
      const parsed = parseJson(result.stdout);
      return textResult(stringify(parsed), { ...result, parsed });
    },
  });

  pi.registerCommand("herdr", {
    description: "Run a herdr CLI command from inside Pi, e.g. /herdr pane list",
    handler: async (args, ctx) => {
      const argv = args.trim().split(/\s+/).filter(Boolean);
      if (argv.length === 0) {
        ctx.ui.notify("Usage: /herdr <status|workspace|tab|pane|wait ...>", "info");
        return;
      }
      try {
        const result = await runHerdr(pi, argv, { cwd: ctx.cwd, timeout: 30_000 });
        ctx.ui.notify(result.stdout || "herdr command completed", "info");
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
      }
    },
  });
}
