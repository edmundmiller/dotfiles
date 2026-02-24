import { describe, expect, it } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  formatPreview,
  formatTime,
  loadStashes,
  nextIdFromStashes,
  parseStashCommand,
  pushStash,
  saveStashes,
  type StashEntry,
} from "../src/logic";

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

function tmpFile(): { path: string; cleanup: () => void } {
  const dir = mkdtempSync(join(tmpdir(), "prompt-stash-test-"));
  const path = join(dir, "stash.json");
  return { path, cleanup: () => rmSync(dir, { recursive: true, force: true }) };
}

function fakeStash(id: number, text: string, timestamp = 1_000_000): StashEntry {
  return { id, text, timestamp };
}

// ---------------------------------------------------------------------------
// loadStashes / saveStashes
// ---------------------------------------------------------------------------

describe("loadStashes", () => {
  // Spec: returns empty array when file doesn't exist
  it("returns [] for missing file", () => {
    expect(loadStashes("/nonexistent/path/stash.json")).toEqual([]);
  });

  // Spec: round-trips correctly
  it("reads back what saveStashes wrote", () => {
    const { path, cleanup } = tmpFile();
    const stashes: StashEntry[] = [fakeStash(1, "first"), fakeStash(2, "second")];
    saveStashes(stashes, path);
    const loaded = loadStashes(path);
    expect(loaded).toEqual(stashes);
    cleanup();
  });

  // Spec: handles empty array
  it("round-trips empty array", () => {
    const { path, cleanup } = tmpFile();
    saveStashes([], path);
    expect(loadStashes(path)).toEqual([]);
    cleanup();
  });

  // Regression: survives a corrupted/partial file
  it("returns [] for corrupt JSON", () => {
    const { path, cleanup } = tmpFile();
    saveStashes([fakeStash(1, "ok")], path);
    Bun.write(path, "{broken json{{{"); // corrupt it
    expect(loadStashes(path)).toEqual([]);
    cleanup();
  });
});

describe("saveStashes", () => {
  // Spec: creates parent directories if needed
  it("creates missing directories", () => {
    const { path, cleanup } = tmpFile();
    const nested = join(path, "nested", "dir", "stash.json");
    saveStashes([fakeStash(1, "hi")], nested);
    const loaded = loadStashes(nested);
    expect(loaded).toHaveLength(1);
    cleanup();
  });
});

// ---------------------------------------------------------------------------
// formatPreview
// ---------------------------------------------------------------------------

describe("formatPreview", () => {
  // Spec: short text is returned as-is
  it("passes through short text unchanged", () => {
    expect(formatPreview("hello world")).toBe("hello world");
  });

  // Spec: newlines replaced with ↵
  it("collapses newlines to ↵", () => {
    expect(formatPreview("line one\nline two")).toBe("line one↵ line two");
  });

  it("collapses multiple consecutive newlines to single ↵", () => {
    expect(formatPreview("a\n\n\nb")).toBe("a↵ b");
  });

  // Spec: truncates at maxLen with ellipsis
  it("truncates at default 60 chars with …", () => {
    const long = "a".repeat(65);
    const result = formatPreview(long);
    expect(result).toHaveLength(61); // 60 + ellipsis char
    expect(result.endsWith("…")).toBe(true);
  });

  it("respects custom maxLen", () => {
    const result = formatPreview("hello world", 5);
    expect(result).toBe("hello…");
  });

  // Spec: exact-length text is not truncated
  it("does not truncate text exactly at maxLen", () => {
    const text = "a".repeat(60);
    expect(formatPreview(text)).toBe(text);
  });

  // Spec: trims leading/trailing whitespace
  it("trims surrounding whitespace", () => {
    expect(formatPreview("  hello  ")).toBe("hello");
  });
});

// ---------------------------------------------------------------------------
// formatTime
// ---------------------------------------------------------------------------

describe("formatTime", () => {
  const now = 1_700_000_000_000; // fixed reference epoch

  // Spec: less than 1 minute ago
  it("returns 'just now' for < 1 minute", () => {
    expect(formatTime(now - 30_000, now)).toBe("just now");
    expect(formatTime(now - 59_999, now)).toBe("just now");
  });

  // Spec: exact 1-minute boundary
  it("returns '1m ago' at exactly 1 minute", () => {
    expect(formatTime(now - 60_000, now)).toBe("1m ago");
  });

  // Spec: minutes range
  it("returns 'Nm ago' for 1–59 minutes", () => {
    expect(formatTime(now - 5 * 60_000, now)).toBe("5m ago");
    expect(formatTime(now - 59 * 60_000, now)).toBe("59m ago");
  });

  // Spec: hours range
  it("returns 'Nh ago' for 1–23 hours", () => {
    expect(formatTime(now - 60 * 60_000, now)).toBe("1h ago");
    expect(formatTime(now - 23 * 60 * 60_000, now)).toBe("23h ago");
  });

  // Spec: older than 24 hours → locale date string
  it("returns a date string for >= 24 hours ago", () => {
    const ts = now - 25 * 60 * 60_000;
    const result = formatTime(ts, now);
    // Should be a date string (not a relative expression)
    expect(result).not.toContain("ago");
    expect(result.length).toBeGreaterThan(3);
  });
});

// ---------------------------------------------------------------------------
// nextIdFromStashes
// ---------------------------------------------------------------------------

describe("nextIdFromStashes", () => {
  it("returns 1 for empty stash list", () => {
    expect(nextIdFromStashes([])).toBe(1);
  });

  it("returns max id + 1", () => {
    const stashes = [fakeStash(3, "c"), fakeStash(1, "a"), fakeStash(5, "e")];
    expect(nextIdFromStashes(stashes)).toBe(6);
  });
});

// ---------------------------------------------------------------------------
// pushStash
// ---------------------------------------------------------------------------

describe("pushStash", () => {
  // Spec: new entry goes to front of list
  it("prepends the new entry", () => {
    const existing = [fakeStash(1, "old")];
    const { stashes } = pushStash(existing, 2, "new");
    expect(stashes[0].text).toBe("new");
    expect(stashes[1].text).toBe("old");
  });

  // Spec: id is set from nextId param, nextId increments
  it("assigns nextId and increments it", () => {
    const { entry, nextId } = pushStash([], 7, "text");
    expect(entry.id).toBe(7);
    expect(nextId).toBe(8);
  });

  // Spec: original array is not mutated
  it("does not mutate the original stash array", () => {
    const original = [fakeStash(1, "old")];
    pushStash(original, 2, "new");
    expect(original).toHaveLength(1);
  });

  // Spec: timestamp is used from param
  it("uses provided timestamp", () => {
    const ts = 1234567890;
    const { entry } = pushStash([], 1, "text", ts);
    expect(entry.timestamp).toBe(ts);
  });

  // Spec: text is preserved exactly
  it("preserves text exactly", () => {
    const text = "Multi-line\nprompt\twith tabs";
    const { entry } = pushStash([], 1, text);
    expect(entry.text).toBe(text);
  });

  // Regression: pushing to non-empty list doesn't lose existing entries
  it("retains all existing entries", () => {
    const existing = [fakeStash(1, "a"), fakeStash(2, "b"), fakeStash(3, "c")];
    const { stashes } = pushStash(existing, 4, "d");
    expect(stashes).toHaveLength(4);
  });
});

// ---------------------------------------------------------------------------
// parseStashCommand (routing)
// ---------------------------------------------------------------------------

describe("parseStashCommand", () => {
  // Spec: /stash → list
  it("empty args → list", () => {
    expect(parseStashCommand("", 0).type).toBe("list");
    expect(parseStashCommand("  ", 0).type).toBe("list");
  });

  // Spec: /stash list → list
  it("'list' keyword → list", () => {
    expect(parseStashCommand("list", 3).type).toBe("list");
  });

  // Spec: /stash <text> → save
  it("non-keyword text → save", () => {
    const action = parseStashCommand("my prompt idea", 0);
    expect(action.type).toBe("save");
    if (action.type === "save") expect(action.text).toBe("my prompt idea");
  });

  // Spec: keywords are not treated as save text
  for (const kw of ["pop", "drop", "clear", "list"]) {
    it(`'${kw}' is not treated as save text`, () => {
      expect(parseStashCommand(kw, 3).type).not.toBe("save");
    });
  }

  describe("pop", () => {
    it("defaults to index 0 (stash 1)", () => {
      const action = parseStashCommand("pop", 2);
      expect(action.type).toBe("pop");
      if (action.type === "pop") expect(action.index).toBe(0);
    });

    it("uses explicit n (1-based → 0-based)", () => {
      const action = parseStashCommand("pop 2", 3);
      expect(action.type).toBe("pop");
      if (action.type === "pop") expect(action.index).toBe(1);
    });

    it("errors when stash is empty", () => {
      expect(parseStashCommand("pop", 0).type).toBe("error");
    });

    it("errors for out-of-range index", () => {
      expect(parseStashCommand("pop 5", 3).type).toBe("error");
    });

    it("errors for index 0", () => {
      expect(parseStashCommand("pop 0", 3).type).toBe("error");
    });

    it("errors for non-numeric n", () => {
      expect(parseStashCommand("pop abc", 3).type).toBe("error");
    });
  });

  describe("drop", () => {
    it("defaults to index 0 (stash 1)", () => {
      const action = parseStashCommand("drop", 1);
      expect(action.type).toBe("drop");
      if (action.type === "drop") expect(action.index).toBe(0);
    });

    it("uses explicit n (1-based → 0-based)", () => {
      const action = parseStashCommand("drop 3", 5);
      expect(action.type).toBe("drop");
      if (action.type === "drop") expect(action.index).toBe(2);
    });

    it("errors when stash is empty", () => {
      expect(parseStashCommand("drop", 0).type).toBe("error");
    });

    it("errors for out-of-range index", () => {
      expect(parseStashCommand("drop 10", 3).type).toBe("error");
    });
  });

  describe("clear", () => {
    it("returns clear action regardless of stash count", () => {
      expect(parseStashCommand("clear", 0).type).toBe("clear");
      expect(parseStashCommand("clear", 99).type).toBe("clear");
    });
  });
});
