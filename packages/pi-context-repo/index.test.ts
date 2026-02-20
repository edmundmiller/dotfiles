import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import {
  type MemoryStatus,
  buildFrontmatter,
  buildTree,
  formatBackupTimestamp,
  installPreCommitHook,
  loadSystemFiles,
  parseFrontmatter,
  scaffoldMemory,
  statusWidget,
  validateFrontmatter,
} from "./index";

// --- helpers ---

const fm = (fields: string) => `---\n${fields}\n---\n\nBody.\n`;

const validFm = fm("description: Test file\nlimit: 3000");

const baseStatus: MemoryStatus = {
  dirty: false,
  files: [],
  aheadOfRemote: false,
  aheadCount: 0,
  hasRemote: false,
  summary: "clean",
};

function tmpMemDir(): string {
  return mkdtempSync(join(tmpdir(), "ctx-repo-"));
}

// --- parseFrontmatter ---

describe("parseFrontmatter", () => {
  test("parses valid frontmatter", () => {
    const { frontmatter, body } = parseFrontmatter(
      `---\ndescription: Test file\nlimit: 3000\n---\n\nSome body.\n`
    );
    expect(frontmatter).toEqual({ description: "Test file", limit: 3000 });
    expect(body).toBe("Some body.\n");
  });

  test.each([
    ["read_only: true", "read_only", true],
    ["limit: 5000", "limit", 5000],
  ])("parses %s", (line, key, expected) => {
    const { frontmatter } = parseFrontmatter(fm(`description: X\n${line}`));
    expect(frontmatter[key]).toBe(expected);
  });

  test("returns empty for content without frontmatter", () => {
    const { frontmatter, body } = parseFrontmatter("Just text.");
    expect(frontmatter).toEqual({});
    expect(body).toBe("Just text.");
  });

  test("handles missing closing delimiter", () => {
    const content = "---\ndescription: Broken\n";
    const { frontmatter, body } = parseFrontmatter(content);
    expect(frontmatter).toEqual({});
    expect(body).toBe(content);
  });
});

// --- buildFrontmatter ---

describe("buildFrontmatter", () => {
  test.each([
    [
      { description: "Test", limit: 2000, read_only: true },
      "---\ndescription: Test\nlimit: 2000\nread_only: true\n---",
    ],
    [{ description: "Test", limit: 3000 }, "---\ndescription: Test\nlimit: 3000\n---"],
    [{}, "---\n---"],
  ])("builds %j", (input, expected) => {
    expect(buildFrontmatter(input)).toBe(expected);
  });

  test("roundtrips with parseFrontmatter", () => {
    const original = { description: "Roundtrip test", limit: 1500 };
    const content = `${buildFrontmatter(original)}\n\nBody text.\n`;
    const { frontmatter } = parseFrontmatter(content);
    expect(frontmatter.description).toBe(original.description);
    expect(frontmatter.limit).toBe(original.limit);
  });
});

// --- validateFrontmatter ---

describe("validateFrontmatter", () => {
  test("passes for valid frontmatter", () => {
    expect(validateFrontmatter(validFm, "test.md")).toEqual([]);
  });

  test.each([
    ["missing frontmatter", "No frontmatter here.", "missing frontmatter"],
    ["unclosed frontmatter", "---\ndescription: Broken\n", "never closed"],
    ["missing description", fm("limit: 3000"), "missing required field 'description'"],
    ["missing limit", fm("description: Test"), "missing required field 'limit'"],
    ["non-positive limit", fm("description: Test\nlimit: 0"), "positive integer"],
    ["unknown keys", fm("description: Test\nlimit: 3000\nauthor: me"), "unknown frontmatter key"],
    [
      "read_only on new file",
      fm("description: Test\nlimit: 3000\nread_only: true"),
      "cannot be set by the agent",
    ],
  ])("rejects %s", (_label, content, errorSubstring) => {
    const errors = validateFrontmatter(content, "test.md");
    expect(errors.some((e) => e.includes(errorSubstring))).toBe(true);
  });

  test("rejects modification of read_only file", () => {
    const existing = fm("description: Protected\nlimit: 1000\nread_only: true");
    const updated = fm("description: Changed\nlimit: 1000\nread_only: true");
    const errors = validateFrontmatter(updated, "test.md", existing);
    expect(errors.some((e) => e.includes("read_only and cannot be modified"))).toBe(true);
  });

  test("rejects changing read_only value", () => {
    const existing = fm("description: Test\nlimit: 1000");
    const updated = fm("description: Test\nlimit: 1000\nread_only: true");
    const errors = validateFrontmatter(updated, "test.md", existing);
    expect(errors.some((e) => e.includes("protected field and cannot be changed"))).toBe(true);
  });

  test("allows updating non-protected fields on existing file", () => {
    const existing = fm("description: Old\nlimit: 1000");
    const updated = fm("description: New\nlimit: 2000");
    expect(validateFrontmatter(updated, "test.md", existing)).toEqual([]);
  });
});

// --- buildTree ---

describe("buildTree", () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = tmpMemDir();
  });
  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  test("returns empty for nonexistent dir", () => {
    expect(buildTree("/nonexistent/path")).toEqual([]);
  });

  test("renders .md files with descriptions", () => {
    writeFileSync(join(tmpDir, "notes.md"), fm("description: My notes\nlimit: 3000"));
    const tree = buildTree(tmpDir);
    expect(tree).toHaveLength(1);
    expect(tree[0]).toContain("notes.md");
    expect(tree[0]).toContain("My notes");
  });

  test("shows directories before files", () => {
    mkdirSync(join(tmpDir, "subdir"));
    writeFileSync(join(tmpDir, "subdir", "child.md"), fm("description: Child\nlimit: 1000"));
    writeFileSync(join(tmpDir, "top.md"), fm("description: Top\nlimit: 1000"));
    const tree = buildTree(tmpDir);
    expect(tree.findIndex((l) => l.includes("subdir/"))).toBeLessThan(
      tree.findIndex((l) => l.includes("top.md"))
    );
  });

  test("marks read-only files", () => {
    writeFileSync(
      join(tmpDir, "protected.md"),
      fm("description: Protected\nlimit: 1000\nread_only: true")
    );
    expect(buildTree(tmpDir)[0]).toContain("[read-only]");
  });

  test.each([
    ["dotfiles", ".hidden", "secret"],
    ["non-.md files", "data.json", "{}"],
  ])("ignores %s", (_label, filename, content) => {
    writeFileSync(join(tmpDir, filename), content);
    writeFileSync(join(tmpDir, "visible.md"), fm("description: Visible\nlimit: 1000"));
    const tree = buildTree(tmpDir);
    expect(tree).toHaveLength(1);
    expect(tree[0]).toContain("visible.md");
  });

  test("renders nested hierarchy", () => {
    mkdirSync(join(tmpDir, "system", "project"), { recursive: true });
    writeFileSync(
      join(tmpDir, "system", "project", "overview.md"),
      fm("description: Overview\nlimit: 2000")
    );
    const tree = buildTree(tmpDir);
    expect(tree.some((l) => l.includes("system/"))).toBe(true);
    expect(tree.some((l) => l.includes("project/"))).toBe(true);
    expect(tree.some((l) => l.includes("overview.md"))).toBe(true);
  });
});

// --- scaffoldMemory ---

describe("scaffoldMemory", () => {
  let memDir: string;

  beforeEach(() => {
    memDir = join(tmpMemDir(), "memory");
  });
  afterEach(() => {
    rmSync(join(memDir, ".."), { recursive: true, force: true });
  });

  test("creates system/ and reference/ directories", () => {
    scaffoldMemory(memDir);
    expect(existsSync(join(memDir, "system"))).toBe(true);
    expect(existsSync(join(memDir, "reference"))).toBe(true);
  });

  test.each([
    ["system/persona.md", "helpful"],
    ["system/user.md", undefined],
    ["reference/README.md", undefined],
  ])("creates %s with valid frontmatter", (relPath, bodyContains) => {
    scaffoldMemory(memDir);
    const content = readFileSync(join(memDir, relPath), "utf-8");
    const { frontmatter, body } = parseFrontmatter(content);
    expect(frontmatter.description).toBeTruthy();
    expect(frontmatter.limit).toBeGreaterThan(0);
    expect(validateFrontmatter(content, relPath)).toEqual([]);
    if (bodyContains) expect(body).toContain(bodyContains);
  });

  test("is idempotent — doesn't overwrite existing files", () => {
    scaffoldMemory(memDir);
    const personaPath = join(memDir, "system", "persona.md");
    writeFileSync(personaPath, fm("description: Custom persona\nlimit: 3000") + "Custom.\n");
    scaffoldMemory(memDir);
    expect(readFileSync(personaPath, "utf-8")).toContain("Custom");
  });
});

// --- loadSystemFiles ---

describe("loadSystemFiles", () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = tmpMemDir();
    mkdirSync(join(tmpDir, "system"), { recursive: true });
  });
  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  test("returns empty for missing system/ dir", () => {
    const empty = tmpMemDir();
    expect(loadSystemFiles(empty)).toBe("");
    rmSync(empty, { recursive: true, force: true });
  });

  test("loads file wrapped in path tags", () => {
    writeFileSync(join(tmpDir, "system", "persona.md"), fm("description: P\nlimit: 3000"));
    const result = loadSystemFiles(tmpDir);
    expect(result).toContain("<system/persona.md>");
    expect(result).toContain("</system/persona.md>");
  });

  test("skips files with empty body", () => {
    writeFileSync(join(tmpDir, "system", "empty.md"), "---\ndescription: E\nlimit: 1000\n---\n\n");
    expect(loadSystemFiles(tmpDir)).toBe("");
  });

  test("loads nested directories recursively", () => {
    mkdirSync(join(tmpDir, "system", "project"), { recursive: true });
    writeFileSync(
      join(tmpDir, "system", "project", "overview.md"),
      fm("description: O\nlimit: 2000")
    );
    expect(loadSystemFiles(tmpDir)).toContain("<system/project/overview.md>");
  });

  test("sorts directories before files", () => {
    mkdirSync(join(tmpDir, "system", "aaa"), { recursive: true });
    writeFileSync(join(tmpDir, "system", "aaa", "nested.md"), fm("description: N\nlimit: 1000"));
    writeFileSync(join(tmpDir, "system", "zzz.md"), fm("description: Z\nlimit: 1000"));
    const result = loadSystemFiles(tmpDir);
    expect(result.indexOf("nested.md")).toBeLessThan(result.indexOf("zzz.md"));
  });
});

// --- statusWidget ---

describe("statusWidget", () => {
  test.each([
    ["clean", {}, "Memory: clean"],
    [
      "uncommitted",
      { dirty: true, files: ["M a.md", "A b.md", "?? c.md"] },
      "Memory: 3 uncommitted",
    ],
    ["unpushed", { hasRemote: true, aheadOfRemote: true, aheadCount: 5 }, "Memory: 5 unpushed"],
    [
      "both",
      { dirty: true, files: ["M f.md"], hasRemote: true, aheadOfRemote: true, aheadCount: 2 },
      "Memory: 1 uncommitted, 2 unpushed",
    ],
  ] as [string, Partial<MemoryStatus>, string][])("shows %s", (_label, overrides, expected) => {
    expect(statusWidget({ ...baseStatus, ...overrides } as MemoryStatus)).toEqual([expected]);
  });
});

// --- formatBackupTimestamp ---

describe("formatBackupTimestamp", () => {
  test.each([
    [new Date(2026, 0, 5, 3, 7, 9), "20260105-030709"],
    [new Date(2026, 11, 25, 14, 30, 59), "20261225-143059"],
  ])("formats %s → %s", (date, expected) => {
    expect(formatBackupTimestamp(date)).toBe(expected);
  });

  test("returns YYYYMMDD-HHMMSS format", () => {
    expect(formatBackupTimestamp()).toMatch(/^\d{8}-\d{6}$/);
  });
});

// --- installPreCommitHook ---

describe("installPreCommitHook", () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = tmpMemDir();
    mkdirSync(join(tmpDir, ".git", "hooks"), { recursive: true });
  });
  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  test("creates executable hook with bash shebang", () => {
    installPreCommitHook(tmpDir);
    const hookPath = join(tmpDir, ".git", "hooks", "pre-commit");
    expect(existsSync(hookPath)).toBe(true);
    expect(statSync(hookPath).mode & 0o100).toBeTruthy();
    expect(readFileSync(hookPath, "utf-8").startsWith("#!/usr/bin/env bash")).toBe(true);
  });

  test.each(["description", "limit", "read_only", "PROTECTED_KEYS"])(
    "hook contains %s validation",
    (keyword) => {
      installPreCommitHook(tmpDir);
      const content = readFileSync(join(tmpDir, ".git", "hooks", "pre-commit"), "utf-8");
      expect(content).toContain(keyword);
    }
  );

  test("creates hooks dir if missing", () => {
    const fresh = tmpMemDir();
    mkdirSync(join(fresh, ".git"));
    installPreCommitHook(fresh);
    expect(existsSync(join(fresh, ".git", "hooks", "pre-commit"))).toBe(true);
    rmSync(fresh, { recursive: true, force: true });
  });

  test("overwrites existing hook (self-healing)", () => {
    const hookPath = join(tmpDir, ".git", "hooks", "pre-commit");
    writeFileSync(hookPath, "#!/bin/bash\necho old");
    installPreCommitHook(tmpDir);
    const content = readFileSync(hookPath, "utf-8");
    expect(content).not.toContain("echo old");
    expect(content).toContain("Validate frontmatter");
  });
});
