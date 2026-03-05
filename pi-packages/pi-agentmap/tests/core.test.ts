import { describe, expect, test } from "bun:test";
import { buildSystemPrompt, truncateYaml, MAX_LINES } from "../src/core";

describe("truncateYaml", () => {
  test("returns short yaml unchanged", () => {
    const yaml = "file: src/index.ts\n  desc: entry point";
    expect(truncateYaml(yaml)).toBe(yaml);
  });

  test("truncates at MAX_LINES and appends marker", () => {
    const lines = Array.from({ length: MAX_LINES + 50 }, (_, i) => `line-${i}`);
    const yaml = lines.join("\n");

    const result = truncateYaml(yaml);
    const resultLines = result.split("\n");

    // MAX_LINES content lines + 1 truncation marker
    expect(resultLines).toHaveLength(MAX_LINES + 1);
    expect(resultLines[MAX_LINES]).toBe("# ... truncated");
    expect(resultLines[0]).toBe("line-0");
    expect(resultLines[MAX_LINES - 1]).toBe(`line-${MAX_LINES - 1}`);
  });

  test("exact MAX_LINES is not truncated", () => {
    const lines = Array.from({ length: MAX_LINES }, (_, i) => `line-${i}`);
    const yaml = lines.join("\n");
    expect(truncateYaml(yaml)).toBe(yaml);
  });

  test("respects custom maxLines", () => {
    const yaml = "a\nb\nc\nd\ne";
    const result = truncateYaml(yaml, 3);
    expect(result).toBe("a\nb\nc\n# ... truncated");
  });

  test("empty string returns empty", () => {
    expect(truncateYaml("")).toBe("");
  });
});

describe("buildSystemPrompt", () => {
  test("appends agentmap XML to existing prompt", () => {
    const result = buildSystemPrompt("You are helpful.", "src/:\n  index.ts");

    expect(result).toStartWith("You are helpful.");
    expect(result).toContain("<agentmap>");
    expect(result).toContain("src/:\n  index.ts");
    expect(result).toContain("</agentmap>");
    expect(result).toContain("<agentmap-instructions>");
    expect(result).toContain("</agentmap-instructions>");
  });

  test("preserves yaml content exactly inside tags", () => {
    const yaml = "root:\n  file.ts:\n    desc: does stuff\n    exports:\n      - main";
    const result = buildSystemPrompt("", yaml);

    expect(result).toContain(yaml);
    // Verify it's wrapped in agentmap tags
    const start = result.indexOf("<agentmap>");
    const end = result.indexOf("</agentmap>");
    const yamlPos = result.indexOf(yaml);
    expect(yamlPos).toBeGreaterThan(start);
    expect(yamlPos).toBeLessThan(end);
  });

  test("works with empty existing prompt", () => {
    const result = buildSystemPrompt("", "map");
    expect(result).toStartWith("\n\n<agentmap>");
  });

  test("instructions mention file description comments", () => {
    const result = buildSystemPrompt("", "yaml");
    expect(result).toContain("description comment at the top");
    expect(result).toContain("header comment");
  });
});
