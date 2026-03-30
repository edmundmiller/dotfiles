const { homedir } = require("os");

const POLL_MS = 3_000;
const HUNK_HOST = process.env.HUNK_MCP_HOST || "127.0.0.1";
const HUNK_PORT = parseInt(process.env.HUNK_MCP_PORT || "47657", 10);
const HUNK_ORIGIN = `http://${HUNK_HOST}:${HUNK_PORT}`;

class HunkSessionWatcher {
  constructor() {
    this.name = "hunk";
    this.ctx = null;
    this.pollTimer = null;
    this.sessions = new Map();
  }

  start(ctx) {
    this.ctx = ctx;
    this.pollTimer = setInterval(() => this.poll(), POLL_MS);
    setTimeout(() => this.poll(), 100);
  }

  stop() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
    this.ctx = null;
  }

  async poll() {
    if (!this.ctx) return;

    let sessions;
    try {
      const res = await fetch(`${HUNK_ORIGIN}/session-api`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ action: "list" }),
      });
      if (!res.ok) return;
      const body = await res.json();
      sessions = body.sessions ?? [];
    } catch {
      // Daemon not running — mark any tracked sessions as done.
      if (this.sessions.size > 0) {
        for (const [id, prev] of this.sessions) {
          if (prev.status !== "done") {
            this.emitForSession(id, prev, "done");
          }
        }
        this.sessions.clear();
      }
      return;
    }

    const seen = new Set();

    for (const s of sessions) {
      seen.add(s.sessionId);

      const projectDir = s.repoRoot || s.cwd;
      if (!projectDir) continue;

      const status = "running";
      const prev = this.sessions.get(s.sessionId);
      const titleChanged = prev?.title !== s.title;
      const statusChanged = prev?.status !== status;

      this.sessions.set(s.sessionId, { status, projectDir, title: s.title });

      if (statusChanged || titleChanged) {
        this.emitForSession(s.sessionId, { projectDir, title: s.title }, status);
      }
    }

    // Sessions that disappeared are done.
    for (const [id, prev] of this.sessions) {
      if (!seen.has(id) && prev.status !== "done") {
        this.emitForSession(id, prev, "done");
        this.sessions.set(id, { ...prev, status: "done" });
      }
    }
  }

  emitForSession(sessionId, info, status) {
    if (!this.ctx) return;

    const session = this.ctx.resolveSession(info.projectDir);
    if (!session) return;

    this.ctx.emit({
      agent: this.name,
      session,
      status,
      ts: Date.now(),
      threadId: sessionId,
      ...(info.title && { threadName: info.title }),
    });
  }
}

module.exports = function registerHunkWatcher(api) {
  api.registerWatcher(new HunkSessionWatcher());
};
