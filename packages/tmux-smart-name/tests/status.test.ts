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

describe("detectStatus", () => {
  // Error patterns
  test.each([
    "Some output\nTraceback (most recent call last):\n",
    "Error: API rate limit exceeded",
    "FATAL ERROR: out of memory",
    "panic: runtime error",
  ])("detects error: %s", (content) => {
    expect(detectStatus(content)).toBe(ICON_ERROR);
  });

  // Waiting patterns
  test.each([
    "Allow once?",
    "Do you want to run this command?",
    "Permission required\nyes › no › skip",
    "Press enter to continue",
  ])("detects waiting: %s", (content) => {
    expect(detectStatus(content)).toBe(ICON_WAITING);
  });

  // Busy patterns
  test.each([
    "Thinking...",
    "Working on task ⠋",
    "≋ Running tools...  Esc to cancel",
    "■■■■■■⬝⬝  esc interrupt\nctrl+p commands",
    "Some output\nEsc to cancel",
    "Working...\n■■■■⬝⬝⬝⬝",
    "Calling tool: Read",
  ])("detects busy: %s", (content) => {
    expect(detectStatus(content)).toBe(ICON_BUSY);
  });

  // Idle patterns
  test.each([
    "Some output\n> ",
    "Completed task\nSession went idle",
    "Some output\n45% of 168k",
    "Created the file\nDone.",
    "ctrl+t variants  tab agents  ctrl+p commands    • OpenCode 1.1.30",
    "Some output\nctrl+p commands",
  ])("detects idle: %s", (content) => {
    expect(detectStatus(content)).toBe(ICON_IDLE);
  });

  test("unknown for ambiguous content", () => {
    expect(detectStatus("Some random output without clear status indicators")).toBe(ICON_UNKNOWN);
  });

  test("unknown for empty content", () => {
    expect(detectStatus("")).toBe(ICON_UNKNOWN);
  });
});

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

describe("stripAnsi", () => {
  test("removes ANSI escapes", () => {
    expect(stripAnsi("\x1b[32mgreen text\x1b[0m normal")).toBe("green text normal");
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
