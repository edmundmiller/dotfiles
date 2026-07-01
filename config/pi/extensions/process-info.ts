// Pi extension: records PID, tmux pane/session, and agent status into session JSONL
// Adapted from https://github.com/richardgill/nix
import type {
  ExtensionAPI,
  ExtensionContext,
  SessionBeforeSwitchEvent,
} from "@mariozechner/pi-coding-agent";

type ProcessInfoEntry = {
  hasUI: boolean;
  pid: number;
  ppid: number;
  tmux: {
    env: string | null;
    pane: string | null;
    session: string | null;
  };
};

type StatusEntry = {
  status: "running" | "stopped";
  isIdle: boolean;
  hasPendingMessages: boolean;
};

type SessionSwitchEntry = {
  reason: SessionBeforeSwitchEvent["reason"];
  targetSessionFile: string | null;
};

const isStaleContextError = (error: unknown): boolean => {
  if (!(error instanceof Error)) return false;
  return error.message.includes("ctx is stale");
};

const appendEntry = <T>(pi: ExtensionAPI, customType: string, data: T): void => {
  try {
    pi.appendEntry(customType, data);
  } catch (error) {
    if (!isStaleContextError(error)) throw error;
  }
};

const resolveTmuxSession = async (
  pi: ExtensionAPI,
  cwd: string,
  tmuxEnv: string | null
): Promise<string | null> => {
  if (!tmuxEnv) return null;
  try {
    const result = await pi.exec("tmux", ["display-message", "-p", "#S"], {
      cwd,
      timeout: 2000,
    });
    if (result.code !== 0) return null;
    const session = result.stdout.trim();
    return session.length > 0 ? session : null;
  } catch {
    return null;
  }
};

const buildProcessInfo = async (
  pi: ExtensionAPI,
  ctx: ExtensionContext
): Promise<ProcessInfoEntry> => {
  const tmuxEnv = process.env.TMUX ?? null;
  const tmuxPane = process.env.TMUX_PANE ?? null;
  const tmuxSession = await resolveTmuxSession(pi, ctx.cwd, tmuxEnv);

  return {
    hasUI: ctx.hasUI,
    pid: process.pid,
    ppid: process.ppid,
    tmux: {
      env: tmuxEnv,
      pane: tmuxPane,
      session: tmuxSession,
    },
  };
};

const buildStatusEntry = (ctx: ExtensionContext, status: StatusEntry["status"]): StatusEntry => ({
  status,
  isIdle: ctx.isIdle(),
  hasPendingMessages: ctx.hasPendingMessages(),
});

const buildSessionSwitchEntry = (event: SessionBeforeSwitchEvent): SessionSwitchEntry => ({
  reason: event.reason,
  targetSessionFile: event.targetSessionFile ?? null,
});

const recordSessionSwitch = (pi: ExtensionAPI, event: SessionBeforeSwitchEvent): void => {
  try {
    const entry = buildSessionSwitchEntry(event);
    appendEntry(pi, "session-switch", entry);
  } catch (error) {
    if (!isStaleContextError(error)) throw error;
  }
};

const recordProcessInfo = async (pi: ExtensionAPI, ctx: ExtensionContext): Promise<void> => {
  try {
    const info = await buildProcessInfo(pi, ctx);
    appendEntry(pi, "process-info", info);
  } catch (error) {
    if (!isStaleContextError(error)) throw error;
  }
};

const recordStatus = (
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  status: StatusEntry["status"]
): void => {
  try {
    const entry = buildStatusEntry(ctx, status);
    appendEntry(pi, "status", entry);
  } catch (error) {
    if (!isStaleContextError(error)) throw error;
  }
};

const processInfoExtension = (pi: ExtensionAPI) => {
  pi.on("session_start", async (_event, ctx) => {
    await recordProcessInfo(pi, ctx);
  });
  pi.on("session_before_switch", (event) => {
    recordSessionSwitch(pi, event);
  });
  pi.on("session_switch", async (_event, ctx) => {
    await recordProcessInfo(pi, ctx);
  });
  pi.on("session_fork", async (_event, ctx) => {
    await recordProcessInfo(pi, ctx);
  });
  pi.on("agent_start", (_event, ctx) => {
    recordStatus(pi, ctx, "running");
  });
  pi.on("agent_end", (_event, ctx) => {
    recordStatus(pi, ctx, "stopped");
  });
};

export default processInfoExtension;
