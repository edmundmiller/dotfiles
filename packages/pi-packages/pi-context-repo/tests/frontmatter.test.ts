/**
 * Unit tests for context-repo frontmatter parsing, building, and validation.
 * These are critical pure functions — frontmatter gates every memory write.
 */

import { describe, expect, test } from "bun:test";
import { parseFrontmatter, buildFrontmatter, validateFrontmatter } from "../index";

// --- parseFrontmatter ---

describe("parseFrontmatter", () => {
  test("parses valid frontmatter", () => {
    const content = "---\ndescription: test file\nlimit: 3000\n---\n\nBody text here.";
    const { frontmatter, body } = parseFrontmatter(content);
    expect(frontmatter.description).toBe("test file");
    expect(frontmatter.limit).toBe(3000);
    expect(body).toBe("Body text here.");
  });

  test("parses read_only flag", () => {
    const content = "---\ndescription: locked\nlimit: 1000\nread_only: true\n---\n\nContent.";
    const { frontmatter } = parseFrontmatter(content);
    expect(frontmatter.read_only).toBe(true);
  });

  test("read_only false when not 'true'", () => {
    const content = "---\ndescription: test\nlimit: 1000\nread_only: false\n---\n\nContent.";
    const { frontmatter } = parseFrontmatter(content);
    expect(frontmatter.read_only).toBe(false);
  });

  test("returns empty frontmatter for no delimiters", () => {
    const content = "Just plain text, no frontmatter.";
    const { frontmatter, body } = parseFrontmatter(content);
    expect(frontmatter).toEqual({});
    expect(body).toBe(content);
  });

  test("handles multiline body", () => {
    const content = "---\ndescription: test\nlimit: 500\n---\n\nLine 1\nLine 2\nLine 3";
    const { body } = parseFrontmatter(content);
    expect(body).toBe("Line 1\nLine 2\nLine 3");
  });

  test("skips lines without colon", () => {
    const content = "---\ndescription: test\nno-colon-line\nlimit: 100\n---\n\nBody";
    const { frontmatter } = parseFrontmatter(content);
    expect(frontmatter.description).toBe("test");
    expect(frontmatter.limit).toBe(100);
  });

  test("handles colons in values", () => {
    const content = "---\ndescription: foo: bar: baz\nlimit: 500\n---\n\nBody";
    const { frontmatter } = parseFrontmatter(content);
    expect(frontmatter.description).toBe("foo: bar: baz");
  });
});

// --- buildFrontmatter ---

describe("buildFrontmatter", () => {
  test("builds complete frontmatter", () => {
    const result = buildFrontmatter({ description: "my file", limit: 2000 });
    expect(result).toBe("---\ndescription: my file\nlimit: 2000\n---");
  });

  test("includes read_only when true", () => {
    const result = buildFrontmatter({ description: "locked", limit: 1000, read_only: true });
    expect(result).toContain("read_only: true");
  });

  test("omits read_only when false", () => {
    const result = buildFrontmatter({ description: "test", limit: 500, read_only: false });
    expect(result).not.toContain("read_only");
  });

  test("omits optional fields when missing", () => {
    const result = buildFrontmatter({});
    expect(result).toBe("---\n---");
  });
});

// --- validateFrontmatter ---

describe("validateFrontmatter", () => {
  test("valid content returns no errors", () => {
    const content = "---\ndescription: test\nlimit: 3000\n---\n\nBody";
    expect(validateFrontmatter(content, "test.md")).toEqual([]);
  });

  test("missing frontmatter delimiter", () => {
    const errors = validateFrontmatter("no frontmatter here", "test.md");
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0]).toContain("missing frontmatter");
  });

  test("unclosed frontmatter", () => {
    const errors = validateFrontmatter("---\ndescription: test\n", "test.md");
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0]).toContain("never closed");
  });

  test("missing description", () => {
    const content = "---\nlimit: 1000\n---\n\nBody";
    const errors = validateFrontmatter(content, "test.md");
    expect(errors.some((e) => e.includes("description"))).toBe(true);
  });

  test("missing limit", () => {
    const content = "---\ndescription: test\n---\n\nBody";
    const errors = validateFrontmatter(content, "test.md");
    expect(errors.some((e) => e.includes("limit"))).toBe(true);
  });

  test("non-positive limit", () => {
    const content = "---\ndescription: test\nlimit: 0\n---\n\nBody";
    const errors = validateFrontmatter(content, "test.md");
    expect(errors.some((e) => e.includes("positive integer"))).toBe(true);
  });

  test("unknown frontmatter key", () => {
    const content = "---\ndescription: test\nlimit: 1000\nfoo: bar\n---\n\nBody";
    const errors = validateFrontmatter(content, "test.md");
    expect(errors.some((e) => e.includes("unknown frontmatter key 'foo'"))).toBe(true);
  });

  test("read_only file blocks modification", () => {
    const newContent = "---\ndescription: updated\nlimit: 1000\n---\n\nNew body";
    const existingContent =
      "---\ndescription: locked\nlimit: 1000\nread_only: true\n---\n\nOld body";
    const errors = validateFrontmatter(newContent, "test.md", existingContent);
    expect(errors.some((e) => e.includes("read_only") && e.includes("cannot be modified"))).toBe(
      true
    );
  });

  test("cannot change read_only flag", () => {
    const newContent = "---\ndescription: test\nlimit: 1000\nread_only: true\n---\n\nBody";
    const existingContent = "---\ndescription: test\nlimit: 1000\n---\n\nBody";
    const errors = validateFrontmatter(newContent, "test.md", existingContent);
    expect(errors.some((e) => e.includes("protected field"))).toBe(true);
  });

  test("valid update to non-read-only file", () => {
    const newContent = "---\ndescription: updated desc\nlimit: 2000\n---\n\nNew body";
    const existingContent = "---\ndescription: old desc\nlimit: 1000\n---\n\nOld body";
    const errors = validateFrontmatter(newContent, "test.md", existingContent);
    expect(errors).toEqual([]);
  });
});
