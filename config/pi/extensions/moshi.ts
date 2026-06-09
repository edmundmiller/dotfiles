import { createHash } from "node:crypto";
import { createConnection } from "node:net";
import { hostname, homedir } from "node:os";
import { join as pathJoin } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

type MoshiCategory =
  | "approval_required"
  | "task_complete"
  | "session_started"
  | "tool_running"
  | "tool_finished";

type MoshiEvent = {
  category: MoshiCategory;
  title: string;
  message: string;
};

type MoshiDaemonResponse = {
  type?: string;
  error?: string;
};

const SOURCE = "pi";
const DEFAULT_BASE_URL = "https://api.getmoshi.app";
const TOOL_EVENT_THROTTLE_MS = 15_000;

let lastToolEventAt = 0;

const token = (): string | undefined => process.env.MOSHI_USER_TOKEN?.trim() || undefined;
const baseUrl = (): string =>
  (process.env.MOSHI_API_BASE_URL?.trim() || DEFAULT_BASE_URL).replace(/\/$/, "");

const shortHash = (value: string): string =>
  createHash("sha256").update(value).digest("hex").slice(0, 12);

const resolveSocketPath = (): string => {
  if (process.env.MOSHI_SOCKET_PATH) return process.env.MOSHI_SOCKET_PATH;
  if (process.platform === "darwin") {
    return pathJoin(homedir(), "Library", "Application Support", "Moshi", "moshi-hook.sock");
  }
  if (process.env.XDG_RUNTIME_DIR) return pathJoin(process.env.XDG_RUNTIME_DIR, "moshi-hook.sock");
  return "/tmp/moshi-hook.sock";
};

const sendEnvelope = (
  envelope: Record<string, unknown>,
  waitTimeoutMs = 1_000
): Promise<MoshiDaemonResponse | null> =>
  new Promise((resolve) => {
    let settled = false;
    const sock = createConnection({ path: resolveSocketPath() });
    const chunks: Buffer[] = [];

    const finish = (value: MoshiDaemonResponse | null) => {
      if (settled) return;
      settled = true;
      try {
        sock.destroy();
      } catch {}
      resolve(value);
    };

    const timeout = setTimeout(() => finish(null), waitTimeoutMs);
    timeout.unref?.();

    sock.setNoDelay(true);
    sock.once("error", () => finish(null));
    sock.once("connect", () => {
      sock.write(JSON.stringify(envelope) + "\n");
      sock.end();
    });
    sock.on("data", (chunk: Buffer) => chunks.push(chunk));

    const parse = () => {
      clearTimeout(timeout);
      const text = Buffer.concat(chunks).toString("utf8").trim();
      if (!text) return finish(null);
      try {
        finish(JSON.parse(text.split("\n")[0]) as MoshiDaemonResponse);
      } catch {
        finish(null);
      }
    };

    sock.once("end", parse);
    sock.once("close", parse);
  });

const getSessionId = (ctx: ExtensionContext): string => {
  const sessionFile = ctx.sessionManager.getSessionFile();
  const basis = sessionFile ?? `${hostname()}:${ctx.cwd}:${process.pid}`;
  return `pi-${shortHash(basis)}`;
};

const getProjectName = (ctx: ExtensionContext): string => {
  const cwd = ctx.cwd.replace(/\/+$/, "");
  return (
    process.env.HERDR_SESSION || process.env.ZELLIJ_SESSION_NAME || cwd.split("/").pop() || cwd
  );
};

const getTerminalContext = () => {
  const herdrActive = process.env.HERDR_ENV === "1";
  const tmuxActive = Boolean(process.env.TMUX);
  const zellijActive = Boolean(process.env.ZELLIJ || process.env.ZELLIJ_SESSION_NAME);

  return {
    terminalKind: tmuxActive ? "tmux" : herdrActive ? "herdr" : zellijActive ? "zellij" : "",
    tmuxSession: "",
    tmuxWindow: "",
    tmuxPane: process.env.TMUX_PANE ?? "",
    tmuxSocket: process.env.TMUX?.split(",", 1)[0] ?? "",
    zellijSession: process.env.ZELLIJ_SESSION_NAME ?? "",
    zellijPane: process.env.ZELLIJ_PANE_ID ?? "",
    herdrSession: herdrActive ? (process.env.HERDR_SESSION ?? "") : "",
    herdrPane: herdrActive ? (process.env.HERDR_PANE_ID ?? "") : "",
    herdrWorkspaceId: herdrActive ? (process.env.HERDR_WORKSPACE_ID ?? "") : "",
    herdrWorkspace: herdrActive ? (process.env.HERDR_WORKSPACE ?? "") : "",
  };
};

const sendLegacyEvent = async (
  ctx: ExtensionContext,
  event: MoshiEvent,
  signal?: AbortSignal
): Promise<{ ok: boolean; error?: string }> => {
  const userToken = token();
  if (!userToken)
    return { ok: false, error: "moshi-hook socket unavailable and MOSHI_USER_TOKEN is not set" };

  const eventId = `${getSessionId(ctx)}-${event.category}-${Date.now()}`;
  const response = await fetch(`${baseUrl()}/api/v1/agent-events`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${userToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      source: SOURCE,
      eventType: "notification",
      sessionId: getSessionId(ctx),
      category: event.category,
      title: event.title,
      message: `[${hostname()}] ${event.message}`,
      eventId,
    }),
    signal,
  });

  if (!response.ok) return { ok: false, error: `Moshi returned HTTP ${response.status}` };
  return { ok: true };
};

const sendMoshiEvent = async (
  ctx: ExtensionContext,
  event: MoshiEvent,
  signal?: AbortSignal
): Promise<{ ok: boolean; error?: string }> => {
  const response = await sendEnvelope({
    type: "session.update",
    source: SOURCE,
    sessionId: getSessionId(ctx),
    eventName: event.category,
    cwd: ctx.cwd,
    projectName: getProjectName(ctx),
    ...getTerminalContext(),
    toolName: "",
    category: event.category,
    title: event.title,
    message: event.message,
    requestedAt: new Date().toISOString(),
  });

  if (response?.error) return { ok: false, error: response.error };
  if (response !== null) return { ok: true };
  return sendLegacyEvent(ctx, event, signal);
};

const notifyMoshi = (ctx: ExtensionContext, event: MoshiEvent, signal?: AbortSignal): void => {
  void sendMoshiEvent(ctx, event, signal).catch((error) => {
    if (ctx.hasUI) ctx.ui.setStatus("moshi", `moshi: ${error.message}`);
  });
};

const shouldSendToolEvent = (): boolean => {
  const now = Date.now();
  if (now - lastToolEventAt < TOOL_EVENT_THROTTLE_MS) return false;
  lastToolEventAt = now;
  return true;
};

export default function moshiExtension(pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setStatus("moshi", "moshi: socket");
    notifyMoshi(ctx, {
      category: "session_started",
      title: "Pi session started",
      message: `Pi session started in ${ctx.cwd}`,
    });
  });

  pi.on("tool_execution_start", (event, ctx) => {
    if (!shouldSendToolEvent()) return;
    notifyMoshi(
      ctx,
      {
        category: "tool_running",
        title: "Pi tool running",
        message: `${event.toolName} is running in ${ctx.cwd}`,
      },
      ctx.signal
    );
  });

  pi.on("tool_execution_end", (event, ctx) => {
    if (!shouldSendToolEvent()) return;
    notifyMoshi(
      ctx,
      {
        category: "tool_finished",
        title: event.isError ? "Pi tool failed" : "Pi tool finished",
        message: `${event.toolName} ${event.isError ? "failed" : "finished"} in ${ctx.cwd}`,
      },
      ctx.signal
    );
  });

  pi.on("agent_end", (_event, ctx) => {
    notifyMoshi(
      ctx,
      {
        category: "task_complete",
        title: "Pi turn complete",
        message: `Pi finished a turn in ${ctx.cwd}`,
      },
      ctx.signal
    );
  });

  pi.registerCommand("moshi", {
    description: "Show Moshi hook status or send a test notification: /moshi [test]",
    handler: async (args, ctx) => {
      if (args.trim() === "test") {
        const result = await sendMoshiEvent(ctx, {
          category: "task_complete",
          title: "Pi Moshi test",
          message: `Test notification from Pi in ${ctx.cwd}`,
        });
        ctx.ui.notify(
          result.ok ? "Sent Moshi test notification" : `Moshi test failed: ${result.error}`,
          result.ok ? "info" : "warning"
        );
        return;
      }

      ctx.ui.notify(
        `Moshi socket: ${resolveSocketPath()}. Use /moshi test to verify. MOSHI_USER_TOKEN is only needed as a fallback.`,
        "info"
      );
    },
  });

  pi.registerTool({
    name: "moshi_notify",
    label: "Moshi Notify",
    description: "Send a Moshi inbox notification for important Pi progress updates.",
    promptSnippet: "Send a Moshi inbox notification for important Pi progress updates",
    promptGuidelines: [
      "Use moshi_notify only for explicit user-requested mobile notifications or important milestones; do not spam routine progress.",
    ],
    parameters: Type.Object({
      category: Type.Union([
        Type.Literal("task_complete"),
        Type.Literal("session_started"),
        Type.Literal("tool_running"),
        Type.Literal("tool_finished"),
      ]),
      title: Type.String({ description: "Short Moshi inbox title" }),
      message: Type.String({ description: "Brief notification body" }),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const result = await sendMoshiEvent(ctx, params, signal);
      return {
        content: [
          {
            type: "text",
            text: result.ok
              ? "Sent Moshi notification."
              : `Moshi notification failed: ${result.error}`,
          },
        ],
        details: { ok: result.ok, error: result.error },
        isError: !result.ok,
      };
    },
  });
}
