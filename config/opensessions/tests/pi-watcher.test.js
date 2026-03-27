const { test, expect } = require("bun:test");
const { appendFile, mkdtemp, rm, writeFile } = require("fs/promises");
const { tmpdir } = require("os");
const { join } = require("path");

const registerPiWatcher = require("../plugins/pi.js");

async function waitFor(condition, timeoutMs = 2_000, stepMs = 25) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    if (condition()) return;
    await Bun.sleep(stepMs);
  }
  throw new Error("timed out waiting for condition");
}

function encode(entries) {
  return `${entries.map((entry) => JSON.stringify(entry)).join("\n")}\n`;
}

async function appendEntries(filePath, entries) {
  await appendFile(filePath, encode(entries), "utf8");
}

async function createHarness({ resolveSession } = {}) {
  const sessionsDir = await mkdtemp(join(tmpdir(), "pi-watcher-test-"));

  let watcher;
  registerPiWatcher({
    registerWatcher(candidate) {
      watcher = candidate;
    },
  });

  if (!watcher) {
    throw new Error("pi watcher was not registered");
  }

  // Keep tests deterministic: no fs.watch callbacks racing with manual processFile calls.
  watcher.setupWatch = () => {};
  watcher.sessionsDir = sessionsDir;

  const events = [];

  watcher.start({
    resolveSession: resolveSession ?? ((projectDir) => ({ id: `session:${projectDir}` })),
    emit(event) {
      events.push(event);
    },
  });

  await waitFor(() => watcher.seeded === true);

  return {
    watcher,
    events,
    sessionsDir,
    async cleanup() {
      watcher.stop();
      await rm(sessionsDir, { recursive: true, force: true });
    },
  };
}

test("registers pi watcher", async () => {
  const harness = await createHarness();
  try {
    expect(harness.watcher.name).toBe("pi");
  } finally {
    await harness.cleanup();
  }
});

test("maps Pi custom status events to opensessions statuses", async () => {
  const projectDir = "/tmp/pi-watcher-status-map";
  const harness = await createHarness({
    resolveSession: (dir) => (dir === projectDir ? { id: "session-1" } : null),
  });

  try {
    const filePath = join(
      harness.sessionsDir,
      "2026-03-27T00-00-00-000Z_11111111-1111-1111-1111-111111111111.jsonl"
    );

    await writeFile(
      filePath,
      encode([
        { type: "session", cwd: projectDir },
        {
          type: "message",
          message: { role: "user", content: [{ type: "text", text: "start" }] },
        },
      ]),
      "utf8"
    );

    await harness.watcher.processFile(filePath);
    expect(harness.events.at(-1)?.status).toBe("running");

    await appendEntries(filePath, [
      {
        type: "custom",
        customType: "status",
        data: { status: "stopped", isIdle: true, hasPendingMessages: false },
      },
    ]);
    await harness.watcher.processFile(filePath);
    expect(harness.events.at(-1)?.status).toBe("done");

    await appendEntries(filePath, [
      {
        type: "custom",
        customType: "status",
        data: { status: "stopped", isIdle: false, hasPendingMessages: false },
      },
    ]);
    await harness.watcher.processFile(filePath);
    expect(harness.events.at(-1)?.status).toBe("waiting");

    await appendEntries(filePath, [
      {
        type: "custom",
        customType: "status",
        data: { status: "stopped", isIdle: false, hasPendingMessages: true },
      },
    ]);
    await harness.watcher.processFile(filePath);
    expect(harness.events.at(-1)?.status).toBe("running");
  } finally {
    await harness.cleanup();
  }
});

test("maps assistant stopReason values", async () => {
  const projectDir = "/tmp/pi-watcher-stop-reasons";
  const harness = await createHarness({
    resolveSession: (dir) => (dir === projectDir ? { id: "session-2" } : null),
  });

  try {
    const filePath = join(harness.sessionsDir, "assistant-stop-reasons.jsonl");

    await writeFile(
      filePath,
      encode([
        { type: "session", cwd: projectDir },
        {
          type: "message",
          message: { role: "user", content: [{ type: "text", text: "start" }] },
        },
      ]),
      "utf8"
    );
    await harness.watcher.processFile(filePath);
    expect(harness.events.at(-1)?.status).toBe("running");

    await appendEntries(filePath, [
      { type: "message", message: { role: "assistant", stopReason: "cancelled" } },
    ]);
    await harness.watcher.processFile(filePath);
    expect(harness.events.at(-1)?.status).toBe("interrupted");

    await appendEntries(filePath, [
      { type: "message", message: { role: "assistant", stopReason: "failed" } },
    ]);
    await harness.watcher.processFile(filePath);
    expect(harness.events.at(-1)?.status).toBe("error");

    await appendEntries(filePath, [
      { type: "message", message: { role: "assistant", stopReason: "tool_use" } },
    ]);
    await harness.watcher.processFile(filePath);
    expect(harness.events.at(-1)?.status).toBe("running");

    await appendEntries(filePath, [
      { type: "message", message: { role: "assistant", stopReason: "end_turn" } },
    ]);
    await harness.watcher.processFile(filePath);
    expect(harness.events.at(-1)?.status).toBe("done");
  } finally {
    await harness.cleanup();
  }
});

test("prefers session_info thread name over other name sources", async () => {
  const projectDir = "/tmp/pi-watcher-thread-name";
  const harness = await createHarness({
    resolveSession: (dir) => (dir === projectDir ? { id: "session-3" } : null),
  });

  try {
    const filePath = join(harness.sessionsDir, "thread-name-precedence.jsonl");

    await writeFile(
      filePath,
      encode([
        { type: "session", cwd: projectDir },
        { type: "session_info", name: "Session Info Title" },
        {
          type: "custom",
          customType: "pi-tmux-window-name/window",
          data: { windowName: "Window Title" },
        },
        {
          type: "message",
          message: {
            role: "user",
            content: [{ type: "text", text: "Prompt Title" }],
          },
        },
      ]),
      "utf8"
    );

    await harness.watcher.processFile(filePath);
    expect(harness.events.at(-1)?.status).toBe("running");
    expect(harness.events.at(-1)?.threadName).toBe("Session Info Title");
  } finally {
    await harness.cleanup();
  }
});

test("does not emit when resolveSession cannot map project", async () => {
  const harness = await createHarness({ resolveSession: () => null });

  try {
    const filePath = join(harness.sessionsDir, "unmapped-project.jsonl");
    await writeFile(
      filePath,
      encode([
        { type: "session", cwd: "/tmp/unmapped-project" },
        {
          type: "message",
          message: { role: "user", content: [{ type: "text", text: "hello" }] },
        },
      ]),
      "utf8"
    );

    await harness.watcher.processFile(filePath);
    expect(harness.events.length).toBe(0);
  } finally {
    await harness.cleanup();
  }
});

test.todo("handles partial-line JSON appends without dropping the completed event");
test.todo("discovers transcripts nested deeper than one directory under sessions root");
test.todo("handles file truncation and resume without stale offsets");
test.todo("deduplicates status transitions when fs.watch and polling race");
test.todo("validates end-to-end updates in a real opensessions sidebar runtime");
