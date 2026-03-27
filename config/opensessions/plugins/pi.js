const { watch } = require("fs");
const { readdir, stat } = require("fs/promises");
const { homedir } = require("os");
const { basename, join } = require("path");

const POLL_MS = 4_000;
const STALE_MS = 5 * 60 * 1000;
const THREAD_NAME_MAX = 80;

function parseThreadId(filePath) {
  const name = basename(filePath, ".jsonl");
  const match = name.match(/[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i);
  return match ? match[0] : name;
}

function normalizeThreadName(text) {
  if (typeof text !== "string") return undefined;
  const firstLine = text
    .split("\n")
    .map((part) => part.trim())
    .find(Boolean);
  return firstLine ? firstLine.slice(0, THREAD_NAME_MAX) : undefined;
}

function extractPromptFromMessageContent(content) {
  if (typeof content === "string") {
    return normalizeThreadName(content);
  }

  if (!Array.isArray(content)) return undefined;

  for (const item of content) {
    if (!item || typeof item !== "object") continue;
    if (item.type !== "text" || typeof item.text !== "string") continue;
    const threadName = normalizeThreadName(item.text);
    if (threadName) return threadName;
  }

  return undefined;
}

function statusFromAssistantStopReason(stopReason, currentStatus) {
  if (typeof stopReason !== "string") return currentStatus;

  if (stopReason === "toolUse" || stopReason === "tool_use") return "running";
  if (stopReason === "stop" || stopReason === "end_turn") return "done";
  if (stopReason === "cancelled" || stopReason === "aborted" || stopReason === "interrupted")
    return "interrupted";
  if (stopReason === "error" || stopReason === "failed") return "error";

  return currentStatus;
}

function statusFromPiStatusEvent(data, currentStatus) {
  const status = data?.status;
  const isIdle = Boolean(data?.isIdle);
  const hasPendingMessages = Boolean(data?.hasPendingMessages);

  if (status === "running") return "running";

  if (status === "stopped") {
    // True terminal idle after assistant output.
    if (isIdle && !hasPendingMessages) return "done";

    // Non-idle "stopped" appears between automated loop turns.
    return hasPendingMessages ? "running" : "waiting";
  }

  return currentStatus;
}

function applyEntries(text, baseSnapshot) {
  let status = baseSnapshot.status;
  let projectDir = baseSnapshot.projectDir;
  let threadName = baseSnapshot.threadName;

  for (const rawLine of text.split("\n")) {
    const line = rawLine.trim();
    if (!line) continue;

    let entry;
    try {
      entry = JSON.parse(line);
    } catch {
      continue;
    }

    if (!projectDir && entry.type === "session" && typeof entry.cwd === "string") {
      projectDir = entry.cwd;
    }

    if (!threadName && entry.type === "session_info" && typeof entry.name === "string") {
      threadName = normalizeThreadName(entry.name) ?? threadName;
    }

    if (
      !threadName &&
      entry.type === "custom" &&
      entry.customType === "pi-tmux-window-name/window" &&
      typeof entry.data?.windowName === "string"
    ) {
      threadName = normalizeThreadName(entry.data.windowName) ?? threadName;
    }

    if (entry.type === "message" && entry.message && typeof entry.message === "object") {
      if (entry.message.role === "user") {
        status = "running";
        if (!threadName) {
          threadName = extractPromptFromMessageContent(entry.message.content) ?? threadName;
        }
      } else if (entry.message.role === "assistant") {
        status = statusFromAssistantStopReason(entry.message.stopReason, status);
      }
    }

    if (entry.type === "custom" && entry.customType === "status") {
      status = statusFromPiStatusEvent(entry.data, status);
    }
  }

  return {
    ...baseSnapshot,
    status,
    projectDir,
    threadName,
  };
}

async function collectSessionFiles(sessionsDir) {
  let entries;
  try {
    entries = await readdir(sessionsDir, { withFileTypes: true });
  } catch {
    return [];
  }

  const files = [];

  for (const entry of entries) {
    const fullPath = join(sessionsDir, entry.name);

    if (entry.isFile() && entry.name.endsWith(".jsonl")) {
      files.push(fullPath);
      continue;
    }

    if (!entry.isDirectory()) continue;

    let nested;
    try {
      nested = await readdir(fullPath, { withFileTypes: true });
    } catch {
      continue;
    }

    for (const file of nested) {
      if (!file.isFile() || !file.name.endsWith(".jsonl")) continue;
      files.push(join(fullPath, file.name));
    }
  }

  return files;
}

class PiAgentWatcher {
  constructor() {
    this.name = "pi";
    this.sessionsDir = process.env.PI_SESSIONS_DIR ?? join(homedir(), ".pi", "agent", "sessions");
    this.sessions = new Map();
    this.fsWatcher = null;
    this.pollTimer = null;
    this.ctx = null;
    this.scanning = false;
    this.seeded = false;
  }

  start(ctx) {
    this.ctx = ctx;
    this.setupWatch();
    setTimeout(() => this.scan(), 50);
    this.pollTimer = setInterval(() => this.scan(), POLL_MS);
  }

  stop() {
    if (this.fsWatcher) {
      try {
        this.fsWatcher.close();
      } catch {}
      this.fsWatcher = null;
    }

    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }

    this.ctx = null;
  }

  async processFile(filePath, fileStat) {
    if (!this.ctx) return;

    let localStat = fileStat;
    if (!localStat) {
      try {
        localStat = await stat(filePath);
      } catch {
        return;
      }
    }

    const threadId = parseThreadId(filePath);
    const previous = this.sessions.get(threadId);

    if (previous && localStat.size === previous.fileSize) return;

    const base = previous
      ? { ...previous, fileSize: localStat.size }
      : { status: "idle", fileSize: localStat.size, projectDir: undefined, threadName: undefined };

    let text;

    if (previous && localStat.size > previous.fileSize) {
      try {
        const buffer = await Bun.file(filePath).arrayBuffer();
        text = new TextDecoder().decode(
          new Uint8Array(buffer).subarray(previous.fileSize, localStat.size)
        );
      } catch {
        return;
      }
    } else {
      try {
        text = await Bun.file(filePath).text();
      } catch {
        return;
      }
    }

    const next = applyEntries(text, base);
    next.fileSize = localStat.size;
    this.sessions.set(threadId, next);

    if (!this.seeded) return;

    const statusChanged = next.status !== previous?.status;
    const nameChanged = next.threadName !== previous?.threadName;
    if (!statusChanged && !nameChanged) return;

    if (!next.projectDir) return;
    const session = this.ctx.resolveSession(next.projectDir);
    if (!session) return;

    // Avoid replaying stale snapshots when we first discover an untouched file.
    if (!previous && next.status === "done") return;

    this.ctx.emit({
      agent: this.name,
      session,
      status: next.status,
      ts: Date.now(),
      threadId,
      ...(next.threadName && { threadName: next.threadName }),
    });
  }

  async scan() {
    if (!this.ctx || this.scanning) return;
    this.scanning = true;

    try {
      const files = await collectSessionFiles(this.sessionsDir);
      const now = Date.now();

      for (const filePath of files) {
        let fileStat;
        try {
          fileStat = await stat(filePath);
        } catch {
          continue;
        }

        const threadId = parseThreadId(filePath);
        const previous = this.sessions.get(threadId);

        if (!previous && now - fileStat.mtimeMs > STALE_MS) continue;

        await this.processFile(filePath, fileStat);
      }
    } finally {
      if (!this.seeded) this.seeded = true;
      this.scanning = false;
    }
  }

  setupWatch() {
    try {
      this.fsWatcher = watch(this.sessionsDir, { recursive: true }, (_eventType, filename) => {
        if (!filename || !filename.endsWith(".jsonl")) return;
        this.processFile(join(this.sessionsDir, filename));
      });
    } catch {
      // Polling still covers environments where recursive fs.watch is unavailable.
    }
  }
}

module.exports = function registerPiWatcher(api) {
  api.registerWatcher(new PiAgentWatcher());
};
