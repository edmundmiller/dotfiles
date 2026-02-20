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

// --- parseFrontmatter ---

describe("parseFrontmatter", () => {
  test("parses valid frontmatter", () => {
    const content = `---
description: Test file
limit: 3000
---

Some body content.
`;
    const { frontmatter, body } = parseFrontmatter(content);
    expect(frontmatter.description).toBe("Test file");
    expect(frontmatter.limit).toBe(3000);
    expect(body).toBe("Some body content.\n");
  });

  test("parses read_only flag", () => {
    const content = `---
description: Protected
limit: 1000
read_only: true
---

Content.
`;
    const { frontmatter } = parseFrontmatter(content);
    expect(frontmatter.read_only).toBe(true);
  });

  test("returns empty frontmatter for content without frontmatter", () => {
    const content = "Just plain text.";
    const { frontmatter, body } = parseFrontmatter(content);
    expect(frontmatter).toEqual({});
    expect(body).toBe("Just plain text.");
  });

  test("handles missing closing delimiter", () => {
    const content = `---
description: Broken
`;
    const { frontmatter, body } = parseFrontmatter(content);
    expect(frontmatter).toEqual({});
    expect(body).toBe(content);
  });

  test("parses limit as integer", () => {
    const content = `---
limit: 5000
description: Numbers
---

Body.
`;
    const { frontmatter } = parseFrontmatter(content);
    expect(frontmatter.limit).toBe(5000);
    expect(typeof frontmatter.limit).toBe("number");
  });
});

// --- buildFrontmatter ---

describe("buildFrontmatter", () => {
  test("builds with all fields", () => {
    const result = buildFrontmatter({ description: "Test", limit: 2000, read_only: true });
    expect(result).toBe("---\ndescription: Test\nlimit: 2000\nread_only: true\n---");
  });

  test("omits read_only when false/undefined", () => {
    const result = buildFrontmatter({ description: "Test", limit: 3000 });
    expect(result).not.toContain("read_only");
  });

  test("omits missing fields", () => {
    const result = buildFrontmatter({});
    expect(result).toBe("---\n---");
  });

  test("roundtrips with parseFrontmatter", () => {
    const original = { description: "Roundtrip test", limit: 1500 };
    const built = buildFrontmatter(original);
    const content = `${built}\n\nBody text.\n`;
    const { frontmatter } = parseFrontmatter(content);
    expect(frontmatter.description).toBe(original.description);
    expect(frontmatter.limit).toBe(original.limit);
  });
});

// --- validateFrontmatter ---

describe("validateFrontmatter", () => {
  const validContent = `---
description: Test file
limit: 3000
---

Content here.
`;

  test("passes for valid frontmatter", () => {
    const errors = validateFrontmatter(validContent, "test.md");
    expect(errors).toEqual([]);
  });

  test("rejects missing frontmatter", () => {
    const errors = validateFrontmatter("No frontmatter here.", "test.md");
    expect(errors).toHaveLength(1);
    expect(errors[0]).toContain("missing frontmatter");
  });

  test("rejects unclosed frontmatter", () => {
    const errors = validateFrontmatter("---\ndescription: Broken\n", "test.md");
    expect(errors).toHaveLength(1);
    expect(errors[0]).toContain("never closed");
  });

  test("rejects missing description", () => {
    const content = `---
limit: 3000
---

Body.
`;
    const errors = validateFrontmatter(content, "test.md");
    expect(errors.some((e) => e.includes("missing required field 'description'"))).toBe(true);
  });

  test("rejects missing limit", () => {
    const content = `---
description: Test
---

Body.
`;
    const errors = validateFrontmatter(content, "test.md");
    expect(errors.some((e) => e.includes("missing required field 'limit'"))).toBe(true);
  });

  test("rejects non-positive limit", () => {
    const content = `---
description: Test
limit: 0
---

Body.
`;
    const errors = validateFrontmatter(content, "test.md");
    expect(errors.some((e) => e.includes("positive integer"))).toBe(true);
  });

  test("rejects unknown frontmatter keys", () => {
    const content = `---
description: Test
limit: 3000
author: me
---

Body.
`;
    const errors = validateFrontmatter(content, "test.md");
    expect(errors.some((e) => e.includes("unknown frontmatter key 'author'"))).toBe(true);
  });

  test("rejects agent setting read_only on new file", () => {
    const content = `---
description: Test
limit: 3000
read_only: true
---

Body.
`;
    const errors = validateFrontmatter(content, "test.md");
    expect(errors.some((e) => e.includes("cannot be set by the agent"))).toBe(true);
  });

  test("rejects modification of read_only file", () => {
    const existing = `---
description: Protected
limit: 1000
read_only: true
---

Old content.
`;
    const updated = `---
description: Changed
limit: 1000
read_only: true
---

New content.
`;
    const errors = validateFrontmatter(updated, "test.md", existing);
    expect(errors.some((e) => e.includes("read_only and cannot be modified"))).toBe(true);
  });

  test("rejects changing read_only value", () => {
    const existing = `---
description: Test
limit: 1000
---

Old content.
`;
    const updated = `---
description: Test
limit: 1000
read_only: true
---

New content.
`;
    const errors = validateFrontmatter(updated, "test.md", existing);
    expect(errors.some((e) => e.includes("protected field and cannot be changed"))).toBe(true);
  });

  test("allows updating non-protected fields on existing file", () => {
    const existing = `---
description: Old description
limit: 1000
---

Old content.
`;
    const updated = `---
description: New description
limit: 2000
---

New content.
`;
    const errors = validateFrontmatter(updated, "test.md", existing);
    expect(errors).toEqual([]);
  });
});

// --- buildTree ---

describe("buildTree", () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = mkdtempSync(join(tmpdir(), "context-repo-test-"));
  });

  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  test("returns empty for nonexistent dir", () => {
    expect(buildTree("/nonexistent/path")).toEqual([]);
  });

  test("renders flat .md files with descriptions", () => {
    writeFileSync(
      join(tmpDir, "notes.md"),
      `---
description: My notes
limit: 3000
---

Notes content.
`
    );
    const tree = buildTree(tmpDir);
    expect(tree).toHaveLength(1);
    expect(tree[0]).toContain("notes.md");
    expect(tree[0]).toContain("My notes");
  });

  test("shows directories before files", () => {
    mkdirSync(join(tmpDir, "subdir"));
    writeFileSync(
      join(tmpDir, "subdir", "child.md"),
      `---
description: Child file
limit: 1000
---

Child.
`
    );
    writeFileSync(
      join(tmpDir, "top.md"),
      `---
description: Top file
limit: 1000
---

Top.
`
    );
    const tree = buildTree(tmpDir);
    const dirIdx = tree.findIndex((l) => l.includes("subdir/"));
    const fileIdx = tree.findIndex((l) => l.includes("top.md"));
    expect(dirIdx).toBeLessThan(fileIdx);
  });

  test("marks read-only files", () => {
    writeFileSync(
      join(tmpDir, "protected.md"),
      `---
description: Protected
limit: 1000
read_only: true
---

Content.
`
    );
    const tree = buildTree(tmpDir);
    expect(tree[0]).toContain("[read-only]");
  });

  test("ignores dotfiles", () => {
    writeFileSync(join(tmpDir, ".hidden"), "secret");
    writeFileSync(
      join(tmpDir, "visible.md"),
      `---
description: Visible
limit: 1000
---

Content.
`
    );
    const tree = buildTree(tmpDir);
    expect(tree).toHaveLength(1);
    expect(tree[0]).toContain("visible.md");
  });

  test("ignores non-.md files", () => {
    writeFileSync(join(tmpDir, "data.json"), "{}");
    writeFileSync(
      join(tmpDir, "notes.md"),
      `---
description: Notes
limit: 1000
---

Content.
`
    );
    const tree = buildTree(tmpDir);
    expect(tree).toHaveLength(1);
    expect(tree[0]).toContain("notes.md");
  });

  test("renders nested hierarchy", () => {
    mkdirSync(join(tmpDir, "system"), { recursive: true });
    mkdirSync(join(tmpDir, "system", "project"), { recursive: true });
    writeFileSync(
      join(tmpDir, "system", "project", "overview.md"),
      `---
description: Project overview
limit: 2000
---

Overview.
`
    );
    const tree = buildTree(tmpDir);
    expect(tree.some((l) => l.includes("system/"))).toBe(true);
    expect(tree.some((l) => l.includes("project/"))).toBe(true);
    expect(tree.some((l) => l.includes("overview.md"))).toBe(true);
  });
});

// --- scaffoldMemory ---

describe("scaffoldMemory", () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = mkdtempSync(join(tmpdir(), "context-repo-scaffold-"));
  });

  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  test("creates system/ and reference/ directories", () => {
    const memDir = join(tmpDir, "memory");
    scaffoldMemory(memDir);
    expect(existsSync(join(memDir, "system"))).toBe(true);
    expect(existsSync(join(memDir, "reference"))).toBe(true);
  });

  test("creates persona.md with valid frontmatter", () => {
    const memDir = join(tmpDir, "memory");
    scaffoldMemory(memDir);
    const content = readFileSync(join(memDir, "system", "persona.md"), "utf-8");
    const { frontmatter, body } = parseFrontmatter(content);
    expect(frontmatter.description).toBeTruthy();
    expect(frontmatter.limit).toBeGreaterThan(0);
    expect(body).toContain("helpful");
    expect(validateFrontmatter(content, "persona.md")).toEqual([]);
  });

  test("creates user.md with valid frontmatter", () => {
    const memDir = join(tmpDir, "memory");
    scaffoldMemory(memDir);
    const content = readFileSync(join(memDir, "system", "user.md"), "utf-8");
    expect(validateFrontmatter(content, "user.md")).toEqual([]);
  });

  test("creates reference/README.md with valid frontmatter", () => {
    const memDir = join(tmpDir, "memory");
    scaffoldMemory(memDir);
    const content = readFileSync(join(memDir, "reference", "README.md"), "utf-8");
    expect(validateFrontmatter(content, "README.md")).toEqual([]);
  });

  test("is idempotent — doesn't overwrite existing files", () => {
    const memDir = join(tmpDir, "memory");
    scaffoldMemory(memDir);

    // Modify a file
    const personaPath = join(memDir, "system", "persona.md");
    writeFileSync(
      personaPath,
      `---
description: Custom persona
limit: 3000
---

Custom content.
`
    );

    // Run again
    scaffoldMemory(memDir);

    // Should keep custom content
    const content = readFileSync(personaPath, "utf-8");
    expect(content).toContain("Custom content");
  });
});

// --- loadSystemFiles ---

describe("loadSystemFiles", () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = mkdtempSync(join(tmpdir(), "context-repo-sysfiles-"));
    mkdirSync(join(tmpDir, "system"), { recursive: true });
  });

  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  test("returns empty for missing system/ dir", () => {
    const empty = mkdtempSync(join(tmpdir(), "context-repo-empty-"));
    expect(loadSystemFiles(empty)).toBe("");
    rmSync(empty, { recursive: true, force: true });
  });

  test("loads single file wrapped in path tags", () => {
    writeFileSync(
      join(tmpDir, "system", "persona.md"),
      `---
description: Persona
limit: 3000
---

Be helpful.
`
    );
    const result = loadSystemFiles(tmpDir);
    expect(result).toContain("<system/persona.md>");
    expect(result).toContain("Be helpful.");
    expect(result).toContain("</system/persona.md>");
  });

  test("skips files with empty body", () => {
    writeFileSync(
      join(tmpDir, "system", "empty.md"),
      `---
description: Empty
limit: 1000
---

`
    );
    const result = loadSystemFiles(tmpDir);
    expect(result).toBe("");
  });

  test("loads nested directories recursively", () => {
    mkdirSync(join(tmpDir, "system", "project"), { recursive: true });
    writeFileSync(
      join(tmpDir, "system", "project", "overview.md"),
      `---
description: Overview
limit: 2000
---

Project overview content.
`
    );
    const result = loadSystemFiles(tmpDir);
    expect(result).toContain("<system/project/overview.md>");
    expect(result).toContain("Project overview content.");
  });

  test("sorts directories before files", () => {
    mkdirSync(join(tmpDir, "system", "aaa"), { recursive: true });
    writeFileSync(
      join(tmpDir, "system", "aaa", "nested.md"),
      `---
description: Nested
limit: 1000
---

Nested content.
`
    );
    writeFileSync(
      join(tmpDir, "system", "zzz.md"),
      `---
description: Top level
limit: 1000
---

Top content.
`
    );
    const result = loadSystemFiles(tmpDir);
    const nestedIdx = result.indexOf("Nested content");
    const topIdx = result.indexOf("Top content");
    expect(nestedIdx).toBeLessThan(topIdx);
  });
});

// --- statusWidget ---

describe("statusWidget", () => {
  const base: MemoryStatus = {
    dirty: false,
    files: [],
    aheadOfRemote: false,
    aheadCount: 0,
    hasRemote: false,
    summary: "clean",
  };

  test("shows clean when no changes", () => {
    expect(statusWidget(base)).toEqual(["Memory: clean"]);
  });

  test("shows uncommitted count", () => {
    const status: MemoryStatus = {
      ...base,
      dirty: true,
      files: ["M system/persona.md", "A system/user.md", "?? reference/new.md"],
    };
    expect(statusWidget(status)).toEqual(["Memory: 3 uncommitted"]);
  });

  test("shows unpushed count", () => {
    const status: MemoryStatus = {
      ...base,
      hasRemote: true,
      aheadOfRemote: true,
      aheadCount: 5,
    };
    expect(statusWidget(status)).toEqual(["Memory: 5 unpushed"]);
  });

  test("shows both uncommitted and unpushed", () => {
    const status: MemoryStatus = {
      ...base,
      dirty: true,
      files: ["M file.md"],
      hasRemote: true,
      aheadOfRemote: true,
      aheadCount: 2,
    };
    expect(statusWidget(status)).toEqual(["Memory: 1 uncommitted, 2 unpushed"]);
  });
});

// --- formatBackupTimestamp ---

describe("formatBackupTimestamp", () => {
  test("formats with zero-padded components", () => {
    const date = new Date(2026, 0, 5, 3, 7, 9); // Jan 5, 2026 03:07:09
    expect(formatBackupTimestamp(date)).toBe("20260105-030709");
  });

  test("handles double-digit months/hours", () => {
    const date = new Date(2026, 11, 25, 14, 30, 59); // Dec 25, 2026 14:30:59
    expect(formatBackupTimestamp(date)).toBe("20261225-143059");
  });

  test("returns consistent length", () => {
    const ts = formatBackupTimestamp();
    // YYYYMMDD-HHMMSS = 15 chars
    expect(ts).toMatch(/^\d{8}-\d{6}$/);
  });
});

// --- installPreCommitHook ---

describe("installPreCommitHook", () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = mkdtempSync(join(tmpdir(), "context-repo-hook-"));
    mkdirSync(join(tmpDir, ".git", "hooks"), { recursive: true });
  });

  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  test("creates executable pre-commit hook", () => {
    installPreCommitHook(tmpDir);
    const hookPath = join(tmpDir, ".git", "hooks", "pre-commit");
    expect(existsSync(hookPath)).toBe(true);
    const stat = statSync(hookPath);
    // Check executable bit (owner)
    expect(stat.mode & 0o100).toBeTruthy();
  });

  test("hook starts with bash shebang", () => {
    installPreCommitHook(tmpDir);
    const hookPath = join(tmpDir, ".git", "hooks", "pre-commit");
    const content = readFileSync(hookPath, "utf-8");
    expect(content.startsWith("#!/usr/bin/env bash")).toBe(true);
  });

  test("hook validates frontmatter fields", () => {
    installPreCommitHook(tmpDir);
    const hookPath = join(tmpDir, ".git", "hooks", "pre-commit");
    const content = readFileSync(hookPath, "utf-8");
    expect(content).toContain("description");
    expect(content).toContain("limit");
    expect(content).toContain("read_only");
    expect(content).toContain("PROTECTED_KEYS");
  });

  test("creates hooks dir if missing", () => {
    const freshDir = mkdtempSync(join(tmpdir(), "context-repo-nohooks-"));
    mkdirSync(join(freshDir, ".git")); // no hooks subdir
    installPreCommitHook(freshDir);
    expect(existsSync(join(freshDir, ".git", "hooks", "pre-commit"))).toBe(true);
    rmSync(freshDir, { recursive: true, force: true });
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
