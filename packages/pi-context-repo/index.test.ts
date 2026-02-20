import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { buildFrontmatter, buildTree, parseFrontmatter, validateFrontmatter } from "./index";

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
    // subdir/ should appear before top.md
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
