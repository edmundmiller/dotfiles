/**
 * Integration tests: pi-context-repo memory tools
 *
 * Tests the full memory lifecycle through the pi-test-harness:
 * system prompt injection, memory_write/delete/commit/search tools,
 * and turn-based reflection reminders.
 *
 * Uses real git repos in temp dirs — no mocking of the extension's
 * own tools. Only standard tools (bash, read, write, edit) are mocked.
 */

import { describe, it, expect, afterEach, beforeEach } from "vitest";
import {
  createTestSession,
  when,
  calls,
  says,
  type TestSession,
} from "@marcfargas/pi-test-harness";
import * as path from "node:path";
import * as fs from "node:fs";
import * as os from "node:os";
import { execSync } from "node:child_process";
import { scaffoldMemory } from "../pi-context-repo/index.js";

const EXTENSION = path.resolve(__dirname, "../pi-context-repo/index.ts");

/** Mock only the standard tools — extension-registered tools run real */
const MOCK_TOOLS = {
  bash: "ok",
  read: "contents",
  write: "written",
  edit: "edited",
};

/** Create a temp dir with .pi/memory scaffolded + git initialized */
function setupMemoryDir(): string {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "ctx-repo-test-"));
  const memDir = path.join(tmp, ".pi", "memory");
  scaffoldMemory(memDir);

  // git init + initial commit so the extension sees an existing repo
  execSync("git init", { cwd: memDir });
  execSync("git add .", { cwd: memDir });
  execSync('git -c user.name="test" -c user.email="t@t" commit -m "init"', {
    cwd: memDir,
  });
  return tmp;
}

/**
 * Save and clear PI_MEMORY_DIR so the extension falls back to cwd + .pi/memory.
 * Without this, the extension reads the real user memory dir.
 */
let savedPiMemoryDir: string | undefined;
function isolateEnv() {
  savedPiMemoryDir = process.env.PI_MEMORY_DIR;
  delete process.env.PI_MEMORY_DIR;
}
function restoreEnv() {
  if (savedPiMemoryDir !== undefined) {
    process.env.PI_MEMORY_DIR = savedPiMemoryDir;
  }
}

describe("pi-context-repo: system prompt injection", () => {
  let t: TestSession;
  let cwd: string;

  beforeEach(() => {
    isolateEnv();
    cwd = setupMemoryDir();
  });

  afterEach(() => {
    t?.dispose();
    if (fs.existsSync(cwd)) fs.rmSync(cwd, { recursive: true, force: true });
    restoreEnv();
  });

  it("injects memory tree and pinned system files into system prompt", async () => {
    let capturedSystemPrompt = "";

    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
      extensionFactories: [
        (pi: any) => {
          pi.on("before_agent_start", async (event: any) => {
            capturedSystemPrompt = event.systemPrompt;
          });
        },
      ],
    });

    await t.run(when("hello", [says("hi")]));

    // Core section header
    expect(capturedSystemPrompt).toContain("## Context Repository (Agent Memory)");
    // Memory tree structure
    expect(capturedSystemPrompt).toContain(".pi/memory/");
    expect(capturedSystemPrompt).toContain("system/");
    // Pinned system files
    expect(capturedSystemPrompt).toContain("### Pinned Memory (system/)");
    expect(capturedSystemPrompt).toContain("<system/persona.md>");
    expect(capturedSystemPrompt).toContain("You are a helpful coding assistant");
    // Guidelines
    expect(capturedSystemPrompt).toContain("### Memory Guidelines");
    expect(capturedSystemPrompt).toContain("memory_write");
  });

  it("includes all scaffolded system files in prompt", async () => {
    let capturedSystemPrompt = "";

    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
      extensionFactories: [
        (pi: any) => {
          pi.on("before_agent_start", async (event: any) => {
            capturedSystemPrompt = event.systemPrompt;
          });
        },
      ],
    });

    await t.run(when("hello", [says("hi")]));

    // All four system files pinned
    expect(capturedSystemPrompt).toContain("<system/persona.md>");
    expect(capturedSystemPrompt).toContain("<system/user.md>");
    expect(capturedSystemPrompt).toContain("<system/project.md>");
    expect(capturedSystemPrompt).toContain("<system/style.md>");
  });
});

describe("pi-context-repo: memory_write tool", () => {
  let t: TestSession;
  let cwd: string;

  beforeEach(() => {
    isolateEnv();
    cwd = setupMemoryDir();
  });

  afterEach(() => {
    t?.dispose();
    if (fs.existsSync(cwd)) fs.rmSync(cwd, { recursive: true, force: true });
    restoreEnv();
  });

  it("writes a new memory file with valid frontmatter", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("remember this", [
        calls("memory_write", {
          path: "reference/notes.md",
          description: "Test notes",
          content: "Some important notes",
        }),
      ])
    );

    const results = t.events.toolResultsFor("memory_write");
    expect(results).toHaveLength(1);
    expect(results[0].isError).toBe(false);
    expect(results[0].text).toContain("Wrote reference/notes.md");

    // Verify file on disk
    const filePath = path.join(cwd, ".pi", "memory", "reference", "notes.md");
    expect(fs.existsSync(filePath)).toBe(true);
    const content = fs.readFileSync(filePath, "utf-8");
    expect(content).toContain("description: Test notes");
    expect(content).toContain("Some important notes");
  });

  it("auto-appends .md extension when omitted", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("write", [
        calls("memory_write", {
          path: "reference/no-ext",
          description: "No extension",
          content: "content",
        }),
      ])
    );

    const results = t.events.toolResultsFor("memory_write");
    expect(results[0].text).toContain("reference/no-ext.md");

    const filePath = path.join(cwd, ".pi", "memory", "reference", "no-ext.md");
    expect(fs.existsSync(filePath)).toBe(true);
  });

  it("rejects write when content exceeds limit", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("write big", [
        calls("memory_write", {
          path: "reference/big.md",
          description: "Big file",
          content: "x".repeat(4000),
          limit: 100,
        }),
      ])
    );

    const results = t.events.toolResultsFor("memory_write");
    expect(results[0].text).toContain("exceeds limit");
  });

  it("rejects write to read_only file", async () => {
    // Create a read_only file manually
    const roPath = path.join(cwd, ".pi", "memory", "system", "locked.md");
    fs.writeFileSync(
      roPath,
      "---\ndescription: Locked\nlimit: 1000\nread_only: true\n---\n\nDo not touch\n"
    );
    execSync("git add . && git -c user.name=t -c user.email=t@t commit -m 'add locked'", {
      cwd: path.join(cwd, ".pi", "memory"),
    });

    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("update locked", [
        calls("memory_write", {
          path: "system/locked.md",
          description: "Try overwrite",
          content: "hacked",
        }),
      ])
    );

    const results = t.events.toolResultsFor("memory_write");
    expect(results[0].text).toContain("read_only");
    expect(results[0].text).toContain("cannot be modified");
  });

  it("auto-stages written file for git commit", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("write staged", [
        calls("memory_write", {
          path: "reference/staged.md",
          description: "Staged test",
          content: "Will be staged",
        }),
      ])
    );

    // Check git status — file should be staged
    const memDir = path.join(cwd, ".pi", "memory");
    const status = execSync("git status --porcelain", { cwd: memDir }).toString().trim();
    expect(status).toContain("reference/staged.md");
    // "A " prefix = staged new file
    expect(status).toMatch(/^A\s/m);
  });
});

describe("pi-context-repo: memory_delete tool", () => {
  let t: TestSession;
  let cwd: string;

  beforeEach(() => {
    isolateEnv();
    cwd = setupMemoryDir();
  });

  afterEach(() => {
    t?.dispose();
    if (fs.existsSync(cwd)) fs.rmSync(cwd, { recursive: true, force: true });
    restoreEnv();
  });

  it("deletes an existing memory file", async () => {
    // Create + commit a file to delete
    const memDir = path.join(cwd, ".pi", "memory");
    const target = path.join(memDir, "reference", "to-delete.md");
    fs.writeFileSync(target, "---\ndescription: Doomed\nlimit: 1000\n---\n\nGoodbye\n");
    execSync("git add . && git -c user.name=t -c user.email=t@t commit -m 'add doomed'", {
      cwd: memDir,
    });

    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(when("delete note", [calls("memory_delete", { path: "reference/to-delete.md" })]));

    const results = t.events.toolResultsFor("memory_delete");
    expect(results).toHaveLength(1);
    expect(results[0].text).toContain("Deleted reference/to-delete.md");

    // File removed from disk
    expect(fs.existsSync(target)).toBe(false);
  });

  it("refuses to delete nonexistent file", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(when("delete ghost", [calls("memory_delete", { path: "reference/ghost.md" })]));

    const results = t.events.toolResultsFor("memory_delete");
    expect(results[0].text).toContain("does not exist");
  });

  it("refuses to delete read_only file", async () => {
    const memDir = path.join(cwd, ".pi", "memory");
    const roFile = path.join(memDir, "reference", "protected.md");
    fs.writeFileSync(
      roFile,
      "---\ndescription: Protected\nlimit: 1000\nread_only: true\n---\n\nSafe\n"
    );
    execSync("git add . && git -c user.name=t -c user.email=t@t commit -m 'add protected'", {
      cwd: memDir,
    });

    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("delete protected", [calls("memory_delete", { path: "reference/protected.md" })])
    );

    const results = t.events.toolResultsFor("memory_delete");
    expect(results[0].text).toContain("read_only");
    expect(results[0].text).toContain("cannot be deleted");

    // File still exists
    expect(fs.existsSync(roFile)).toBe(true);
  });
});

describe("pi-context-repo: memory_commit tool", () => {
  let t: TestSession;
  let cwd: string;

  beforeEach(() => {
    isolateEnv();
    cwd = setupMemoryDir();
  });

  afterEach(() => {
    t?.dispose();
    if (fs.existsSync(cwd)) fs.rmSync(cwd, { recursive: true, force: true });
    restoreEnv();
  });

  it("commits staged changes with message", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    // Write then commit in sequence
    await t.run(
      when("save note", [
        calls("memory_write", {
          path: "reference/committed.md",
          description: "Committed note",
          content: "Important data",
        }),
      ]),
      when("commit it", [calls("memory_commit", { message: "add: committed note" })])
    );

    const writeResults = t.events.toolResultsFor("memory_write");
    expect(writeResults[0].isError).toBe(false);

    const commitResults = t.events.toolResultsFor("memory_commit");
    expect(commitResults).toHaveLength(1);
    expect(commitResults[0].text).toContain("Committed: add: committed note");

    // Verify git log contains the commit message
    const memDir = path.join(cwd, ".pi", "memory");
    const log = execSync("git log --oneline -1", { cwd: memDir }).toString().trim();
    expect(log).toContain("add: committed note");
  });

  it("creates empty commit when nothing staged (pi.exec does not throw)", async () => {
    // NOTE: pi.exec returns { code, stdout, stderr } without throwing on
    // non-zero exit. The extension's catch block for "nothing to commit"
    // is dead code — git commit -m on clean tree returns code 1 but doesn't
    // throw. This test documents actual behavior, not ideal behavior.
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(when("commit nothing", [calls("memory_commit", { message: "empty commit" })]));

    const results = t.events.toolResultsFor("memory_commit");
    // Since pi.exec doesn't throw, this "succeeds" with Committed: message
    expect(results[0].text).toContain("Committed: empty commit");
  });
});

describe("pi-context-repo: memory_search tool", () => {
  let t: TestSession;
  let cwd: string;

  beforeEach(() => {
    isolateEnv();
    cwd = setupMemoryDir();
  });

  afterEach(() => {
    t?.dispose();
    if (fs.existsSync(cwd)) fs.rmSync(cwd, { recursive: true, force: true });
    restoreEnv();
  });

  it("finds files matching search term", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    // Write a file with searchable content, commit so git grep can find it
    await t.run(
      when("write searchable", [
        calls("memory_write", {
          path: "reference/searchable.md",
          description: "Searchable content",
          content: "The quick brown fox jumps over the lazy dog",
        }),
      ]),
      when("commit", [calls("memory_commit", { message: "add searchable" })]),
      when("search for fox", [calls("memory_search", { query: "fox" })])
    );

    const results = t.events.toolResultsFor("memory_search");
    expect(results).toHaveLength(1);
    expect(results[0].text).toContain("searchable.md");
    expect(results[0].text).toContain("Searchable content");
  });

  it("returns no matches for unknown term", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(when("search nothing", [calls("memory_search", { query: "xyzzynonexistent" })]));

    const results = t.events.toolResultsFor("memory_search");
    expect(results[0].text).toContain("No memory files matching");
  });
});

describe("pi-context-repo: memory_list tool", () => {
  let t: TestSession;
  let cwd: string;

  beforeEach(() => {
    isolateEnv();
    cwd = setupMemoryDir();
  });

  afterEach(() => {
    t?.dispose();
    if (fs.existsSync(cwd)) fs.rmSync(cwd, { recursive: true, force: true });
    restoreEnv();
  });

  it("lists memory files with descriptions", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("write file", [
        calls("memory_write", {
          path: "reference/listable.md",
          description: "Listable note",
          content: "content",
        }),
      ]),
      when("list files", [calls("memory_list", {})])
    );

    const results = t.events.toolResultsFor("memory_list");
    expect(results).toHaveLength(1);
    expect(results[0].text).toContain("Found");
    expect(results[0].text).toContain("reference/listable.md");
    expect(results[0].text).toContain("Listable note");
  });

  it("supports directory-scoped listing", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("write file", [
        calls("memory_write", {
          path: "reference/scoped.md",
          description: "Scoped note",
          content: "content",
        }),
      ]),
      when("list reference", [calls("memory_list", { directory: "reference" })])
    );

    const result = t.events.toolResultsFor("memory_list")[0];
    expect(result.text).toContain("reference/scoped.md");
    expect(result.text).not.toContain("system/persona.md");
  });

  it("rejects directories outside memory root", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(when("escape", [calls("memory_list", { directory: "../" })]));

    const result = t.events.toolResultsFor("memory_list")[0];
    expect(result.text).toContain("escapes memory root");
  });
});

describe("pi-context-repo: memory_read tool", () => {
  let t: TestSession;
  let cwd: string;

  beforeEach(() => {
    isolateEnv();
    cwd = setupMemoryDir();
  });

  afterEach(() => {
    t?.dispose();
    if (fs.existsSync(cwd)) fs.rmSync(cwd, { recursive: true, force: true });
    restoreEnv();
  });

  it("reads a memory file with metadata", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(when("read persona", [calls("memory_read", { path: "system/persona.md" })]));

    const result = t.events.toolResultsFor("memory_read")[0];
    expect(result.text).toContain("Path: system/persona.md");
    expect(result.text).toContain("Description:");
    expect(result.text).toContain("You are a helpful coding assistant");
  });

  it("auto-appends .md extension", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(when("read persona", [calls("memory_read", { path: "system/persona" })]));

    const result = t.events.toolResultsFor("memory_read")[0];
    expect(result.text).toContain("Path: system/persona.md");
  });

  it("returns error for missing file", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(when("read missing", [calls("memory_read", { path: "reference/missing.md" })]));

    const result = t.events.toolResultsFor("memory_read")[0];
    expect(result.text).toContain("does not exist");
  });
});

describe("pi-context-repo: reflection reminders", () => {
  let t: TestSession;
  let cwd: string;

  beforeEach(() => {
    isolateEnv();
    cwd = setupMemoryDir();
    // Set reflection interval to 3 for quick test
    const settingsPath = path.join(cwd, ".pi", "memory", ".settings.json");
    fs.writeFileSync(settingsPath, JSON.stringify({ reflectionInterval: 3 }));
  });

  afterEach(() => {
    t?.dispose();
    if (fs.existsSync(cwd)) fs.rmSync(cwd, { recursive: true, force: true });
    restoreEnv();
  });

  it("injects reflection reminder at configured interval", async () => {
    const capturedPrompts: string[] = [];

    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
      extensionFactories: [
        (pi: any) => {
          pi.on("before_agent_start", async (event: any) => {
            capturedPrompts.push(event.systemPrompt);
          });
        },
      ],
    });

    // Run 4 turns — reflection should appear at turn 3
    await t.run(
      when("turn 1", [says("ok 1")]),
      when("turn 2", [says("ok 2")]),
      when("turn 3", [says("ok 3")]),
      when("turn 4", [says("ok 4")])
    );

    // Turn 3 (index 2) should have reflection
    expect(capturedPrompts[2]).toContain("MEMORY REFLECTION");
    // Turns 1, 2, 4 should not
    expect(capturedPrompts[0]).not.toContain("MEMORY REFLECTION");
    expect(capturedPrompts[1]).not.toContain("MEMORY REFLECTION");
    expect(capturedPrompts[3]).not.toContain("MEMORY REFLECTION");
  });
});

describe("pi-context-repo: multi-tool sequences", () => {
  let t: TestSession;
  let cwd: string;

  beforeEach(() => {
    isolateEnv();
    cwd = setupMemoryDir();
  });

  afterEach(() => {
    t?.dispose();
    if (fs.existsSync(cwd)) fs.rmSync(cwd, { recursive: true, force: true });
    restoreEnv();
  });

  it("write → commit → search → delete flow", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    // 1. Write
    await t.run(
      when("create note", [
        calls("memory_write", {
          path: "reference/lifecycle.md",
          description: "Lifecycle test note",
          content: "Lifecycle content for testing the full flow",
        }),
      ])
    );
    expect(t.events.toolResultsFor("memory_write")[0].text).toContain("Wrote");

    // 2. Commit
    await t.run(when("commit note", [calls("memory_commit", { message: "add: lifecycle note" })]));
    expect(t.events.toolResultsFor("memory_commit")[0].text).toContain("Committed");

    // 3. Search — finds the committed file
    await t.run(when("search lifecycle", [calls("memory_search", { query: "Lifecycle" })]));
    const searchResult = t.events.toolResultsFor("memory_search")[0];
    expect(searchResult.text).toContain("lifecycle.md");

    // 4. Delete
    await t.run(when("delete note", [calls("memory_delete", { path: "reference/lifecycle.md" })]));
    expect(t.events.toolResultsFor("memory_delete")[0].text).toContain("Deleted");

    // Verify file is gone
    const filePath = path.join(cwd, ".pi", "memory", "reference", "lifecycle.md");
    expect(fs.existsSync(filePath)).toBe(false);
  });

  it("system prompt updates after write reflects new file in tree", async () => {
    const capturedPrompts: string[] = [];

    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
      extensionFactories: [
        (pi: any) => {
          pi.on("before_agent_start", async (event: any) => {
            capturedPrompts.push(event.systemPrompt);
          });
        },
      ],
    });

    // Turn 1: before write — no custom file in tree
    await t.run(when("before write", [says("ready")]));
    expect(capturedPrompts[0]).not.toContain("custom-note.md");

    // Turn 2: write a new file
    await t.run(
      when("write custom", [
        calls("memory_write", {
          path: "reference/custom-note.md",
          description: "Custom note",
          content: "Custom content",
        }),
      ])
    );

    // Turn 3: after write — file should appear in tree
    await t.run(when("after write", [says("done")]));
    expect(capturedPrompts[2]).toContain("custom-note.md");
  });

  it("tool sequence is correct across multi-turn flow", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("step 1", [
        calls("memory_write", {
          path: "reference/seq.md",
          description: "Sequence test",
          content: "seq data",
        }),
      ]),
      when("step 2", [calls("memory_commit", { message: "add seq" })]),
      when("step 3", [calls("memory_search", { query: "seq" })])
    );

    expect(t.events.toolSequence()).toEqual(["memory_write", "memory_commit", "memory_search"]);
  });
});

describe("pi-context-repo: memory_log tool", () => {
  let t: TestSession;
  let cwd: string;

  beforeEach(() => {
    isolateEnv();
    cwd = setupMemoryDir();
  });

  afterEach(() => {
    t?.dispose();
    if (fs.existsSync(cwd)) fs.rmSync(cwd, { recursive: true, force: true });
    restoreEnv();
  });

  it("shows commit history", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    // Write + commit to create history
    await t.run(
      when("write", [
        calls("memory_write", {
          path: "reference/logged.md",
          description: "Log test",
          content: "will appear in log",
        }),
      ]),
      when("commit", [calls("memory_commit", { message: "feat: add logged note" })]),
      when("show log", [calls("memory_log", {})])
    );

    const results = t.events.toolResultsFor("memory_log");
    expect(results).toHaveLength(1);
    expect(results[0].text).toContain("feat: add logged note");
    // Should also show the initial scaffold commit
    expect(results[0].text).toContain("init");
  });
});

describe("pi-context-repo: memory_backup tool", () => {
  let t: TestSession;
  let cwd: string;

  beforeEach(() => {
    isolateEnv();
    cwd = setupMemoryDir();
  });

  afterEach(() => {
    t?.dispose();
    if (fs.existsSync(cwd)) fs.rmSync(cwd, { recursive: true, force: true });
    restoreEnv();
  });

  it("creates a timestamped backup", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd,
      mockTools: MOCK_TOOLS,
    });

    await t.run(when("backup", [calls("memory_backup", {})]));

    const results = t.events.toolResultsFor("memory_backup");
    expect(results).toHaveLength(1);
    expect(results[0].text).toContain("Backup created: backup-");

    // Verify backup dir exists
    const backupDir = path.join(cwd, ".pi", "memory-backups");
    expect(fs.existsSync(backupDir)).toBe(true);
    const entries = fs.readdirSync(backupDir);
    expect(entries.length).toBe(1);
    expect(entries[0]).toMatch(/^backup-\d{8}-\d{6}$/);
  });
});
