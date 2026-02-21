/**
 * Pi extension: exposes agent status via filesystem for tmux-smart-name.
 *
 * Writes a tiny JSON file to /tmp/pi-tmux-status/<TMUX_PANE>.json on every
 * state transition (agent_start, agent_end, session_shutdown). tmux-smart-name
 * reads this file instead of parsing pane content with regex — faster, more
 * reliable, and no false positives from scrollback artifacts.
 *
 * Status file format:
 *   { "status": "busy"|"idle"|"waiting", "pid": number, "ts": number,
 *     "session"?: string, "cwd"?: string, "model"?: string }
 *
 * The file is cleaned up on session_shutdown and process exit.
 */
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { mkdirSync, writeFileSync, unlinkSync, existsSync } from "node:fs";

const STATUS_DIR = "/tmp/pi-tmux-status";

type AgentStatus = "busy" | "idle" | "waiting";

interface StatusFile {
  status: AgentStatus;
  pid: number;
  ts: number;
  session?: string;
  cwd?: string;
  model?: string;
}

let statusPath: string | null = null;
let lastModel: string | undefined;

function writeStatus(status: AgentStatus, extra?: Partial<StatusFile>): void {
  if (!statusPath) return;
  try {
    const data: StatusFile = {
      status,
      pid: process.pid,
      ts: Date.now(),
      ...extra,
    };
    if (lastModel) data.model = lastModel;
    writeFileSync(statusPath, JSON.stringify(data) + "\n");
  } catch {
    // /tmp not writable or race condition — silently ignore
  }
}

function cleanupStatus(): void {
  if (!statusPath) return;
  try {
    if (existsSync(statusPath)) unlinkSync(statusPath);
  } catch {
    // already gone
  }
  statusPath = null;
}

export default function tmuxStatus(pi: ExtensionAPI) {
  const pane = process.env.TMUX_PANE;
  if (!pane) return; // not running in tmux — nothing to do

  // Sanitize pane ID for filename (e.g. "%417" → "417")
  const safePane = pane.replace(/[^a-zA-Z0-9_-]/g, "");
  statusPath = `${STATUS_DIR}/${safePane}.json`;

  // Ensure directory exists
  try {
    mkdirSync(STATUS_DIR, { recursive: true });
  } catch {
    // already exists or no permission
  }

  // ── Event handlers ─────────────────────────────────────────────────────

  pi.on("session_start", (_event, ctx) => {
    writeStatus("idle", {
      cwd: ctx.cwd,
      session: ctx.sessionManager?.getSessionFile() ?? undefined,
    });
  });

  pi.on("agent_start", (_event, ctx) => {
    writeStatus("busy", { cwd: ctx.cwd });
  });

  pi.on("agent_end", (_event, ctx) => {
    // Check if there are pending messages (follow-ups queued).
    // If so, agent will start again shortly — stay busy to avoid flicker.
    if (ctx.hasPendingMessages()) {
      writeStatus("busy", { cwd: ctx.cwd });
    } else {
      writeStatus("idle", { cwd: ctx.cwd });
    }
  });

  pi.on("model_select", (event) => {
    lastModel = `${event.model.provider}/${event.model.id}`;
  });

  // Tool permission prompts → waiting status.
  // The tool_call handler fires before tool execution. If the extension
  // environment shows a confirmation dialog, the agent is "waiting".
  // We can't detect this generically from tool_call alone (the dialog is
  // in another extension), but we can detect auto_compaction and auto_retry
  // which are system-level wait states.

  pi.on("auto_compaction_start", () => {
    writeStatus("busy"); // compacting is still "busy" from the user's perspective
  });

  pi.on("auto_retry_start", () => {
    writeStatus("waiting"); // waiting for retry delay
  });

  pi.on("auto_retry_end", () => {
    // Will transition to busy (if retrying) or idle (if failed) via agent events
  });

  // ── Cleanup ────────────────────────────────────────────────────────────

  pi.on("session_shutdown", () => {
    cleanupStatus();
  });

  // Belt-and-suspenders: also clean up on process exit
  process.on("exit", cleanupStatus);
  process.on("SIGTERM", () => {
    cleanupStatus();
    process.exit(0);
  });
}
