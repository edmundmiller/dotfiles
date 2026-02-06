import { describe, expect, test } from "bun:test";
import {
  detectStatus,
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
  test("busy: spinner + Working...", () => {
    expect(detectStatus("⠦ Working...", "pi")).toBe(ICON_BUSY);
  });

  test("busy: steering queued", () => {
    const content = `Steering: How far are we
↳ Alt+Up to edit all queued messages

⠙ Working...`;
    expect(detectStatus(content, "pi")).toBe(ICON_BUSY);
  });

  test("idle: status bar with anthropic model", () => {
    const content = `done.

────────────────────────────────────────────────────
~/obsidian-vault (main)
↑34 ↓5.2k R928k W33k $0.799 (sub) 19.5%/200k (auto)
(anthropic) claude-opus-4-6 • medium
LSP`;
    expect(detectStatus(content, "pi")).toBe(ICON_IDLE);
  });

  test("idle: status bar with openai model", () => {
    const content = `committed: 587b427 on em-branch-1
working tree clean.

────────────────────────────────────────────────────
~/src/personal/hledger (gitbutler/workspace)
↑599k ↓47k R17M $4.678 (sub) 54.4%/272k (auto)
(openai-codex) gpt-5.3-codex • xhigh
LSP pyright, beancount MCP: 0/1 servers`;
    expect(detectStatus(content, "pi")).toBe(ICON_IDLE);
  });

  test("idle: cost line present", () => {
    const content = `↑343 ↓20k R11M W820k $10.960 (sub) 13.9%/1.0M (auto)`;
    expect(detectStatus(content, "pi")).toBe(ICON_IDLE);
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

// ── Priority ───────────────────────────────────────────────────────────────

describe("prioritize", () => {
  test.each([
    [[], ICON_IDLE],
    [[ICON_IDLE], ICON_IDLE],
    [[ICON_BUSY, ICON_IDLE], ICON_BUSY],
    [[ICON_WAITING, ICON_BUSY], ICON_WAITING],
    [[ICON_UNKNOWN, ICON_WAITING], ICON_UNKNOWN],
    [[ICON_ERROR, ICON_UNKNOWN], ICON_ERROR],
    [[ICON_IDLE, ICON_BUSY, ICON_WAITING, ICON_ERROR], ICON_ERROR],
  ] as const)("%j → %s", (input, expected) => {
    expect(prioritize([...input])).toBe(expected);
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
