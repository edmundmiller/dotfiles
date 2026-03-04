/**
 * pi-git-ai Extension
 *
 * Integrates with git-ai (https://usegitai.com) to track AI code authorship.
 * Calls `git-ai checkpoint agent-v1` before and after file edits so git-ai
 * can attribute changes to the AI agent vs human.
 *
 * Before edit: marks pending changes as human-authored
 * After edit: marks changes as AI-authored with transcript, model, session ID
 *
 * Silently skips if git-ai is not installed.
 */

import type { ExtensionAPI, ToolCallEvent } from "@mariozechner/pi-coding-agent";
import { spawn } from "node:child_process";

// Runtime import for type guard
const { isToolCallEventType: isToolCall } = await import("@mariozechner/pi-coding-agent");

// --- git-ai agent-v1 preset types ---

export interface HumanCheckpoint {
  type: "human";
  repo_working_dir: string;
  will_edit_filepaths?: string[];
}

export interface AiAgentCheckpoint {
  type: "ai_agent";
  repo_working_dir: string;
  edited_filepaths: string[];
  transcript: { messages: TranscriptMessage[] };
  agent_name: string;
  model: string;
  conversation_id: string;
}

export type TranscriptMessage =
  | { type: "user"; text: string; timestamp?: string }
  | { type: "assistant"; text: string; timestamp?: string }
  | { type: "thinking"; text: string; timestamp?: string }
  | { type: "tool_use"; name: string; input: Record<string, unknown>; timestamp?: string };

// --- Helpers (exported for testing) ---

/** Extract file paths from a tool call event. Empty array = not a file-editing tool. */
export function getEditedPaths(event: ToolCallEvent): string[] {
  if (isToolCall("edit", event)) return [event.input.path];
  if (isToolCall("write", event)) return [event.input.path];
  if (event.toolName === "apply_patch") {
    const patch = (event.input as Record<string, unknown>).patch;
    if (typeof patch !== "string") return [];
    const paths: string[] = [];
    for (const m of patch.matchAll(/\*\*\* (?:Update|Add|Delete) File: (.+)/g)) {
      const p = m[1]?.trim();
      if (p) paths.push(p);
    }
    return paths;
  }
  return [];
}

/** Run git-ai checkpoint with JSON payload on stdin. */
export function runCheckpoint(payload: HumanCheckpoint | AiAgentCheckpoint): Promise<void> {
  return new Promise<void>((resolve) => {
    const child = spawn("git-ai", ["checkpoint", "agent-v1"], {
      stdio: ["pipe", "ignore", "ignore"],
    });
    child.stdin.write(JSON.stringify(payload));
    child.stdin.end();
    child.on("close", () => resolve());
    child.on("error", () => resolve()); // non-fatal
  });
}

/** Convert pi session entries to git-ai transcript format.
 *  Filters out tool results per git-ai spec. */
export function buildTranscript(
  entries: Array<{ type: string; message?: { role: string; content: unknown; timestamp?: number } }>
): TranscriptMessage[] {
  const out: TranscriptMessage[] = [];

  for (const entry of entries) {
    if (entry.type !== "message" || !entry.message) continue;
    const msg = entry.message;
    const ts = msg.timestamp ? new Date(msg.timestamp).toISOString() : undefined;

    if (msg.role === "user") {
      const text =
        typeof msg.content === "string"
          ? msg.content
          : Array.isArray(msg.content)
            ? (msg.content as Array<{ type: string; text?: string }>)
                .filter((c) => c.type === "text" && c.text)
                .map((c) => c.text!)
                .join("\n")
            : "";
      if (text) out.push({ type: "user", text, timestamp: ts });
    } else if (msg.role === "assistant") {
      if (!Array.isArray(msg.content)) continue;
      const parts = msg.content as Array<{
        type: string;
        text?: string;
        thinking?: string;
        name?: string;
        arguments?: Record<string, unknown>;
      }>;

      const textParts = parts.filter((c) => c.type === "text" && c.text);
      if (textParts.length > 0) {
        out.push({
          type: "assistant",
          text: textParts.map((c) => c.text!).join("\n"),
          timestamp: ts,
        });
      }
      for (const t of parts.filter((c) => c.type === "thinking" && c.thinking)) {
        out.push({ type: "thinking", text: t.thinking!, timestamp: ts });
      }
      for (const tc of parts.filter((c) => c.type === "toolCall" && c.name)) {
        out.push({
          type: "tool_use",
          name: tc.name!,
          input: tc.arguments ?? {},
          timestamp: ts,
        });
      }
    }
    // Skip toolResult — git-ai explicitly excludes them
  }
  return out;
}

export default function (pi: ExtensionAPI) {
  let gitAiAvailable: boolean | null = null;
  const pendingPaths = new Map<string, string[]>();

  async function isAvailable(): Promise<boolean> {
    if (gitAiAvailable !== null) return gitAiAvailable;
    try {
      await pi.exec("git-ai", ["--version"]);
      gitAiAvailable = true;
    } catch {
      gitAiAvailable = false;
    }
    return gitAiAvailable;
  }

  // Before file edit: store paths + mark pending changes as human
  pi.on("tool_call", async (event) => {
    const paths = getEditedPaths(event);
    if (paths.length === 0) return;
    if (!(await isAvailable())) return;

    pendingPaths.set(event.toolCallId, paths);

    await runCheckpoint({
      type: "human",
      repo_working_dir: process.cwd(),
      will_edit_filepaths: paths,
    });
  });

  // After file edit: mark changes as AI-authored with transcript
  pi.on("tool_execution_end", async (event, ctx) => {
    const paths = pendingPaths.get(event.toolCallId);
    if (!paths) return;
    pendingPaths.delete(event.toolCallId);

    if (event.isError) return;
    if (!(await isAvailable())) return;

    await runCheckpoint({
      type: "ai_agent",
      repo_working_dir: process.cwd(),
      edited_filepaths: paths,
      transcript: { messages: buildTranscript(ctx.sessionManager.getBranch() as any) },
      agent_name: "pi",
      model: ctx.model?.id ?? "unknown",
      conversation_id: ctx.sessionManager.getSessionId(),
    });
  });

  pi.on("agent_end", async () => {
    pendingPaths.clear();
    gitAiAvailable = null;
  });
}
