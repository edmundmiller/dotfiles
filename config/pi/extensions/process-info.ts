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

let extensionApi: ExtensionAPI | null = null;

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

const recordSessionSwitch = (event: SessionBeforeSwitchEvent): void => {
  if (!extensionApi) return;
  const entry = buildSessionSwitchEntry(event);
  extensionApi.appendEntry("session-switch", entry);
};

const recordProcessInfo = async (ctx: ExtensionContext): Promise<void> => {
  if (!extensionApi) return;
  const info = await buildProcessInfo(extensionApi, ctx);
  extensionApi.appendEntry("process-info", info);
};

const recordStatus = (ctx: ExtensionContext, status: StatusEntry["status"]): void => {
  if (!extensionApi) return;
  const entry = buildStatusEntry(ctx, status);
  extensionApi.appendEntry("status", entry);
};

const processInfoExtension = (pi: ExtensionAPI) => {
  extensionApi = pi;
  pi.on("session_start", async (_event, ctx) => {
    await recordProcessInfo(ctx);
  });
  pi.on("session_before_switch", (event) => {
    recordSessionSwitch(event);
  });
  pi.on("session_switch", async (_event, ctx) => {
    await recordProcessInfo(ctx);
  });
  pi.on("session_fork", async (_event, ctx) => {
    await recordProcessInfo(ctx);
  });
  pi.on("agent_start", (_event, ctx) => {
    recordStatus(ctx, "running");
  });
  pi.on("agent_end", (_event, ctx) => {
    recordStatus(ctx, "stopped");
  });
};

export default processInfoExtension;
