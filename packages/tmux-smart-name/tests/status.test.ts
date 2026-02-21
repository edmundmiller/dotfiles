import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { readFileSync, mkdirSync, writeFileSync, rmSync, utimesSync } from "node:fs";
import { join } from "node:path";
import {
  detectStatus,
  readPiStatusFile,
  prioritize,
  stripAnsi,
  colorize,
  ICON_IDLE,
  ICON_BUSY,
  ICON_WAITING,
  ICON_ERROR,
  ICON_UNKNOWN,
  ICON_COLORS,
} from "../src/status";

// ── Shared patterns (any agent) ────────────────────────────────────────────

describe("detectStatus (shared)", () => {
  test.each([
    "Traceback (most recent call last):\n  File...",
    "Error: API rate limit exceeded",
    "FATAL ERROR: out of memory",
    "panic: runtime error",
  ])("error: %s", (content) => {
    expect(detectStatus(content)).toBe(ICON_ERROR);
  });

  test.each([
    "Allow once?",
    "Do you want to run this command?",
    "Permission required\nyes › no › skip",
    "Press enter to continue",
  ])("waiting: %s", (content) => {
    expect(detectStatus(content)).toBe(ICON_WAITING);
  });

  test("unknown for empty", () => {
    expect(detectStatus("")).toBe(ICON_UNKNOWN);
  });

  test("unknown for ambiguous", () => {
    expect(detectStatus("random output with no patterns")).toBe(ICON_UNKNOWN);
  });
});

// ── pi-specific ────────────────────────────────────────────────────────────

describe("detectStatus (pi)", () => {
  // Busy: Loader component renders "⠦ Working... (Escape to interrupt)"
  test("busy: spinner + Working...", () => {
    expect(detectStatus("⠦ Working...", "pi")).toBe(ICON_BUSY);
  });

  test("busy: Working with interrupt hint", () => {
    expect(detectStatus("⠹ Working... (Escape to interrupt)", "pi")).toBe(ICON_BUSY);
  });

  test("busy: auto-compacting", () => {
    expect(detectStatus("⠧ Auto-compacting... (Escape to cancel)", "pi")).toBe(ICON_BUSY);
  });

  test("busy: retrying", () => {
    expect(detectStatus("⠋ Retrying (1/3) in 5s... (Escape to cancel)", "pi")).toBe(ICON_BUSY);
  });

  test("busy: summarizing branch", () => {
    expect(detectStatus("⠙ Summarizing branch... (Escape to cancel)", "pi")).toBe(ICON_BUSY);
  });

  test("busy: steering queued", () => {
    const content = `Steering: How far are we
↳ Alt+Up to edit all queued messages

⠙ Working...`;
    expect(detectStatus(content, "pi")).toBe(ICON_BUSY);
  });

  test("busy: follow-up queued", () => {
    const content = `Follow-up: Also check the tests
↳ Alt+Up to edit all queued messages`;
    expect(detectStatus(content, "pi")).toBe(ICON_BUSY);
  });

  test("busy: tool output truncated (earlier lines)", () => {
    expect(detectStatus("... (3 earlier lines, ctrl+o to expand)", "pi")).toBe(ICON_BUSY);
  });

  test("busy: tool output truncated (more lines)", () => {
    expect(detectStatus("... (5 more lines, ctrl+o to expand)", "pi")).toBe(ICON_BUSY);
  });

  test("idle: earlier lines marker does not override footer", () => {
    const content = `Some earlier output
... (20 earlier lines, ctrl+o to expand)
Claude │ 5h 4h21m left ━━━━━━━ 0% used │ Week 6d10h left ━━━━━━━ 0% used
~/obsidian-vault (main)
↑38 ↓4.1k R1.0M W94k $1.206 (sub) 19.0%/200k (auto)
(anthropic) claude-opus-4-6 • medium
LSP typescript`;
    expect(detectStatus(content, "pi")).toBe(ICON_IDLE);
  });

  // Idle: Footer component renders stats + model info
  test("idle: footer with anthropic model", () => {
    const content = `done.

────────────────────────────────────────────────────
~/obsidian-vault (main)
↑34 ↓5.2k R928k W33k $0.799 (sub) 19.5%/200k (auto)
(anthropic) claude-opus-4-6 • medium
LSP`;
    expect(detectStatus(content, "pi")).toBe(ICON_IDLE);
  });

  test("idle: footer with openai model + MCP", () => {
    const content = `committed: 587b427 on em-branch-1
working tree clean.

────────────────────────────────────────────────────
~/src/personal/hledger (gitbutler/workspace)
↑599k ↓47k R17M $4.678 (sub) 54.4%/272k (auto)
(openai-codex) gpt-5.3-codex • xhigh
LSP pyright, beancount MCP: 0/1 servers`;
    expect(detectStatus(content, "pi")).toBe(ICON_IDLE);
  });

  test("idle: cost + context usage", () => {
    expect(detectStatus("↑343 ↓20k R11M W820k $10.960 (sub) 13.9%/1.0M (auto)", "pi")).toBe(
      ICON_IDLE
    );
  });

  test("idle: cost without sub", () => {
    expect(detectStatus("↑12 ↓1.5k $0.042 0.5%/200k (auto)", "pi")).toBe(ICON_IDLE);
  });

  test("idle: LSP indicator", () => {
    expect(detectStatus("LSP", "pi")).toBe(ICON_IDLE);
  });

  test("idle: MCP indicator", () => {
    expect(detectStatus("MCP: 2/3 servers", "pi")).toBe(ICON_IDLE);
  });

  // ── Fixture tests (real captured pane content) ─────────────────────────
  test.each([
    // file, expected — add rows as new fixtures are captured
    ["pi-idle.txt", ICON_IDLE], // contains weak-busy in scrollback; footer wins
  ] as const)("fixture %s → %s", (file, expected) => {
    const fixture = readFileSync(join(import.meta.dir, "fixtures", file), "utf8");
    expect(detectStatus(fixture, "pi")).toBe(expected);
  });
});

// ── Claude Code-specific ───────────────────────────────────────────────────

describe("detectStatus (claude)", () => {
  test("busy: tool output marker", () => {
    expect(detectStatus("⎿ Reading file.ts", "claude")).toBe(ICON_BUSY);
  });

  test("busy: Esc to cancel", () => {
    expect(detectStatus("Some output\nEsc to cancel", "claude")).toBe(ICON_BUSY);
  });

  test("busy: Calling tool", () => {
    expect(detectStatus("Calling tool: Read", "claude")).toBe(ICON_BUSY);
  });

  test("idle: prompt", () => {
    expect(detectStatus("Done editing.\n> ", "claude")).toBe(ICON_IDLE);
  });

  test("idle: token usage", () => {
    expect(detectStatus("45% of 168k", "claude")).toBe(ICON_IDLE);
  });

  test("idle: How can I help", () => {
    expect(detectStatus("How can I help you today?", "claude")).toBe(ICON_IDLE);
  });
});

// ── Amp-specific ───────────────────────────────────────────────────────────

describe("detectStatus (amp)", () => {
  test("busy: streaming indicator + Running tools", () => {
    expect(detectStatus("≋ Running tools...  Esc to cancel", "amp")).toBe(ICON_BUSY);
  });

  test("busy: progress bar + esc interrupt", () => {
    expect(detectStatus("■■■■■■⬝⬝  esc interrupt\nctrl+p commands", "amp")).toBe(ICON_BUSY);
  });

  test("idle: ctrl+p commands footer", () => {
    expect(detectStatus("Some output\nctrl+p commands", "amp")).toBe(ICON_IDLE);
  });

  test("idle: ctrl+t variants footer", () => {
    expect(detectStatus("ctrl+t variants  tab agents  ctrl+p commands", "amp")).toBe(ICON_IDLE);
  });
});

// ── OpenCode-specific ──────────────────────────────────────────────────────

describe("detectStatus (opencode)", () => {
  test("idle: OpenCode version", () => {
    expect(detectStatus("• OpenCode 1.1.30", "opencode")).toBe(ICON_IDLE);
  });

  test("busy: Tool execution", () => {
    expect(detectStatus("Tool: read file.ts", "opencode")).toBe(ICON_BUSY);
  });
});

// ── Codex-specific ──────────────────────────────────────────────────────

describe("detectStatus (codex)", () => {
  test("busy: esc to interrupt", () => {
    expect(detectStatus("tab to add notes\nesc to interrupt", "codex")).toBe(ICON_BUSY);
  });

  test("waiting: patch approval prompt", () => {
    expect(detectStatus("Allow Codex to apply proposed code changes?", "codex")).toBe(ICON_WAITING);
  });

  test("idle: composer footer", () => {
    expect(detectStatus("tab to add notes\nCompose new task", "codex")).toBe(ICON_IDLE);
  });
});

// ── Priority ───────────────────────────────────────────────────────────────

describe("prioritize", () => {
  test.each([
    [[], ICON_IDLE],
    [[ICON_IDLE], ICON_IDLE],
    [[ICON_BUSY, ICON_IDLE], ICON_BUSY],
    [[ICON_WAITING, ICON_BUSY], ICON_WAITING],
    [[ICON_UNKNOWN, ICON_WAITING], ICON_WAITING],
    [[ICON_ERROR, ICON_UNKNOWN], ICON_ERROR],
    [[ICON_IDLE, ICON_BUSY, ICON_WAITING, ICON_ERROR], ICON_ERROR],
  ] as const)("%j → %s", (input, expected) => {
    expect(prioritize([...input])).toBe(expected);
  });
});

// ── Status file bridge ─────────────────────────────────────────────────────

describe("readPiStatusFile", () => {
  const testDir = "/tmp/pi-tmux-status";
  const testPaneId = "%999";
  const testFile = join(testDir, "999.json");

  beforeEach(() => {
    mkdirSync(testDir, { recursive: true });
  });

  afterEach(() => {
    try {
      rmSync(testFile);
    } catch {
      // already gone
    }
  });

  test("returns ICON_BUSY for busy status", () => {
    writeFileSync(testFile, JSON.stringify({ status: "busy", pid: 1234, ts: Date.now() }));
    expect(readPiStatusFile(testPaneId)).toBe(ICON_BUSY);
  });

  test("returns ICON_IDLE for idle status", () => {
    writeFileSync(testFile, JSON.stringify({ status: "idle", pid: 1234, ts: Date.now() }));
    expect(readPiStatusFile(testPaneId)).toBe(ICON_IDLE);
  });

  test("returns ICON_WAITING for waiting status", () => {
    writeFileSync(testFile, JSON.stringify({ status: "waiting", pid: 1234, ts: Date.now() }));
    expect(readPiStatusFile(testPaneId)).toBe(ICON_WAITING);
  });

  test("returns null for missing file", () => {
    expect(readPiStatusFile("%nonexistent")).toBeNull();
  });

  test("returns null for stale file (>30s old)", () => {
    writeFileSync(testFile, JSON.stringify({ status: "busy", pid: 1234, ts: Date.now() }));
    // Backdate the file modification time by 60 seconds
    const past = new Date(Date.now() - 60_000);
    utimesSync(testFile, past, past);
    expect(readPiStatusFile(testPaneId)).toBeNull();
  });

  test("returns null for malformed JSON", () => {
    writeFileSync(testFile, "not json");
    expect(readPiStatusFile(testPaneId)).toBeNull();
  });

  test("returns null for unknown status value", () => {
    writeFileSync(testFile, JSON.stringify({ status: "exploded", pid: 1234, ts: Date.now() }));
    expect(readPiStatusFile(testPaneId)).toBeNull();
  });
});

// ── Utilities ──────────────────────────────────────────────────────────────

describe("stripAnsi", () => {
  test("removes ANSI escapes", () => {
    expect(stripAnsi("\x1b[32mgreen\x1b[0m normal")).toBe("green normal");
  });

  test("removes control chars, keeps newlines", () => {
    expect(stripAnsi("line1\x00\x1f\nline2")).toBe("line1\nline2");
  });

  test("preserves unicode", () => {
    const text = "─────╯\n● □ ■ ▲ ◇";
    expect(stripAnsi(text)).toBe(text);
  });
});

describe("colorize", () => {
  test.each([
    [ICON_IDLE, ICON_COLORS[ICON_IDLE]],
    [ICON_BUSY, ICON_COLORS[ICON_BUSY]],
    [ICON_WAITING, ICON_COLORS[ICON_WAITING]],
    [ICON_ERROR, ICON_COLORS[ICON_ERROR]],
    [ICON_UNKNOWN, ICON_COLORS[ICON_UNKNOWN]],
  ] as const)("%s → colored", (icon, expected) => {
    expect(colorize(icon)).toBe(expected);
  });
});
