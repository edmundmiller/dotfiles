const { test, expect, mock, beforeEach, afterEach } = require("bun:test");

const registerHunkWatcher = require("../plugins/hunk.js");

function createHarness({ resolveSession } = {}) {
  let watcher;
  registerHunkWatcher({
    registerWatcher(candidate) {
      watcher = candidate;
    },
  });

  if (!watcher) {
    throw new Error("hunk watcher was not registered");
  }

  // Disable automatic polling — tests drive poll() manually.
  const originalStart = watcher.start.bind(watcher);
  watcher.start = function (ctx) {
    this.ctx = ctx;
  };

  const events = [];

  watcher.start({
    resolveSession: resolveSession ?? ((projectDir) => `session:${projectDir}`),
    emit(event) {
      events.push(event);
    },
  });

  return {
    watcher,
    events,
    cleanup() {
      watcher.stop();
    },
  };
}

// Stash original fetch so we can restore it.
const originalFetch = globalThis.fetch;

afterEach(() => {
  globalThis.fetch = originalFetch;
});

function mockFetch(sessions) {
  globalThis.fetch = mock(() =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve({ sessions }),
    })
  );
}

function mockFetchError() {
  globalThis.fetch = mock(() => Promise.reject(new Error("connection refused")));
}

test("registers hunk watcher with correct name", () => {
  const harness = createHarness();
  try {
    expect(harness.watcher.name).toBe("hunk");
  } finally {
    harness.cleanup();
  }
});

test("emits running when daemon reports a live session", async () => {
  const projectDir = "/tmp/my-project";
  const harness = createHarness({
    resolveSession: (dir) => (dir === projectDir ? "session-1" : null),
  });

  try {
    mockFetch([
      {
        sessionId: "abc-123",
        cwd: projectDir,
        repoRoot: projectDir,
        title: "diff --staged",
        fileCount: 3,
        snapshot: {},
      },
    ]);

    await harness.watcher.poll();

    expect(harness.events.length).toBe(1);
    expect(harness.events[0].agent).toBe("hunk");
    expect(harness.events[0].status).toBe("running");
    expect(harness.events[0].threadId).toBe("abc-123");
    expect(harness.events[0].threadName).toBe("diff --staged");
    expect(harness.events[0].session).toBe("session-1");
  } finally {
    harness.cleanup();
  }
});

test("does not re-emit when session unchanged between polls", async () => {
  const projectDir = "/tmp/stable-project";
  const harness = createHarness({
    resolveSession: (dir) => (dir === projectDir ? "session-1" : null),
  });

  try {
    mockFetch([
      {
        sessionId: "s-1",
        cwd: projectDir,
        repoRoot: projectDir,
        title: "show HEAD",
        fileCount: 1,
        snapshot: {},
      },
    ]);

    await harness.watcher.poll();
    expect(harness.events.length).toBe(1);

    await harness.watcher.poll();
    expect(harness.events.length).toBe(1);
  } finally {
    harness.cleanup();
  }
});

test("emits done when session disappears from daemon", async () => {
  const projectDir = "/tmp/vanish-project";
  const harness = createHarness({
    resolveSession: (dir) => (dir === projectDir ? "session-1" : null),
  });

  try {
    mockFetch([
      {
        sessionId: "s-gone",
        cwd: projectDir,
        repoRoot: projectDir,
        title: "diff",
        fileCount: 2,
        snapshot: {},
      },
    ]);

    await harness.watcher.poll();
    expect(harness.events.length).toBe(1);
    expect(harness.events[0].status).toBe("running");

    // Session disappears.
    mockFetch([]);
    await harness.watcher.poll();

    expect(harness.events.length).toBe(2);
    expect(harness.events[1].status).toBe("done");
    expect(harness.events[1].threadId).toBe("s-gone");
  } finally {
    harness.cleanup();
  }
});

test("emits done for all sessions when daemon goes away", async () => {
  const harness = createHarness({
    resolveSession: (dir) => `session:${dir}`,
  });

  try {
    mockFetch([
      {
        sessionId: "s-a",
        cwd: "/tmp/a",
        repoRoot: "/tmp/a",
        title: "diff",
        fileCount: 1,
        snapshot: {},
      },
      {
        sessionId: "s-b",
        cwd: "/tmp/b",
        repoRoot: "/tmp/b",
        title: "show",
        fileCount: 1,
        snapshot: {},
      },
    ]);

    await harness.watcher.poll();
    expect(harness.events.length).toBe(2);

    // Daemon crashes.
    mockFetchError();
    await harness.watcher.poll();

    const doneEvents = harness.events.filter((e) => e.status === "done");
    expect(doneEvents.length).toBe(2);
  } finally {
    harness.cleanup();
  }
});

test("does not emit when resolveSession returns null", async () => {
  const harness = createHarness({ resolveSession: () => null });

  try {
    mockFetch([
      {
        sessionId: "s-unmapped",
        cwd: "/tmp/unmapped",
        repoRoot: "/tmp/unmapped",
        title: "diff",
        fileCount: 1,
        snapshot: {},
      },
    ]);

    await harness.watcher.poll();
    expect(harness.events.length).toBe(0);
  } finally {
    harness.cleanup();
  }
});

test("prefers repoRoot over cwd for project directory", async () => {
  let resolvedDir;
  const harness = createHarness({
    resolveSession: (dir) => {
      resolvedDir = dir;
      return "session-1";
    },
  });

  try {
    mockFetch([
      {
        sessionId: "s-repo",
        cwd: "/tmp/repo/subdir",
        repoRoot: "/tmp/repo",
        title: "diff",
        fileCount: 1,
        snapshot: {},
      },
    ]);

    await harness.watcher.poll();
    expect(resolvedDir).toBe("/tmp/repo");
  } finally {
    harness.cleanup();
  }
});

test("falls back to cwd when repoRoot is absent", async () => {
  let resolvedDir;
  const harness = createHarness({
    resolveSession: (dir) => {
      resolvedDir = dir;
      return "session-1";
    },
  });

  try {
    mockFetch([
      {
        sessionId: "s-cwd",
        cwd: "/tmp/no-repo",
        title: "patch -",
        fileCount: 1,
        snapshot: {},
      },
    ]);

    await harness.watcher.poll();
    expect(resolvedDir).toBe("/tmp/no-repo");
  } finally {
    harness.cleanup();
  }
});

test("emits when title changes on same session", async () => {
  const projectDir = "/tmp/title-change";
  const harness = createHarness({
    resolveSession: (dir) => (dir === projectDir ? "session-1" : null),
  });

  try {
    mockFetch([
      {
        sessionId: "s-title",
        cwd: projectDir,
        repoRoot: projectDir,
        title: "diff --staged",
        fileCount: 1,
        snapshot: {},
      },
    ]);

    await harness.watcher.poll();
    expect(harness.events.length).toBe(1);
    expect(harness.events[0].threadName).toBe("diff --staged");

    // Title changes after reload.
    mockFetch([
      {
        sessionId: "s-title",
        cwd: projectDir,
        repoRoot: projectDir,
        title: "show HEAD~1",
        fileCount: 2,
        snapshot: {},
      },
    ]);

    await harness.watcher.poll();
    expect(harness.events.length).toBe(2);
    expect(harness.events[1].threadName).toBe("show HEAD~1");
  } finally {
    harness.cleanup();
  }
});

test("no-ops gracefully when daemon never started", async () => {
  const harness = createHarness();

  try {
    mockFetchError();
    await harness.watcher.poll();
    expect(harness.events.length).toBe(0);
  } finally {
    harness.cleanup();
  }
});
