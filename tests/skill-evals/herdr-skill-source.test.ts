import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { ARM_SOURCES, MINIMAL_SKILL_TEXT, renderArmContext } from "./herdr-skill-arms";
import { HALLUCINATED_COMMANDS, STALE_SYNTAX } from "./herdr-skill-cases";

const root = fileURLToPath(new URL("../..", import.meta.url));
const skillDir = `${root}/skills/conditional/herdr/herdr`;
const docs = [
  "SKILL.md",
  "references/cli-map.md",
  "references/recipes.md",
  "references/pi-workspace.md",
].map((rel) => ({ rel, text: readFileSync(`${skillDir}/${rel}`, "utf8") }));

const scripts = [
  "agent_context.py",
  "extract_ids.py",
  "monitor_pane.py",
  "send_prompt_to_pane.py",
  "start_pi_workspace.py",
  "write_handoff_prompt.py",
].map((rel) => ({ rel, text: readFileSync(`${skillDir}/scripts/${rel}`, "utf8") }));

/**
 * Prose legitimately names dead commands to warn against them ("There is no
 * layout export/apply in 0.7.5"). Only fenced code blocks are prescriptive, so
 * staleness is asserted against those.
 */
function codeBlocks(markdown: string): string {
  const blocks = markdown.match(/```[a-z]*\n[\s\S]*?```/g) ?? [];
  return blocks.join("\n");
}

describe("herdr skill matches the installed 0.7.5 CLI surface", () => {
  for (const { rel, text } of docs) {
    const runnable = codeBlocks(text);

    it(`${rel} has runnable examples to check`, () => {
      expect(runnable.length).toBeGreaterThan(0);
    });

    it(`${rel} runs no command removed in 0.7.5`, () => {
      const found = HALLUCINATED_COMMANDS.filter((c) => runnable.includes(c));
      expect(found).toEqual([]);
    });

    it(`${rel} uses no pre-0.7.5 flag spelling in examples`, () => {
      for (const stale of STALE_SYNTAX) {
        expect(runnable.includes(stale), `${rel} example contains "${stale}"`).toBe(false);
      }
    });
  }

  it("documents --until rather than --status for agent waits", () => {
    for (const { rel, text } of docs) {
      const runnable = codeBlocks(text);
      if (!runnable.includes("agent wait")) continue;
      expect(runnable.includes("--status"), `${rel} uses --status`).toBe(false);
    }
  });
});

describe("herdr skill scripts follow repo runtime conventions", () => {
  for (const { rel, text } of scripts) {
    it(`${rel} uses the uv PEP 723 shebang`, () => {
      expect(text.startsWith("#!/usr/bin/env -S uv run --script\n")).toBe(true);
      expect(text).toContain("# /// script");
      expect(text).toContain("# requires-python =");
    });

    it(`${rel} builds agent waits with --until`, () => {
      if (!text.includes('"wait"')) return;
      expect(text).toContain('"--until"');
      expect(text.includes('"--status"')).toBe(false);
    });
  }

  it("no script invokes a top-level herdr wait group", () => {
    for (const { rel, text } of scripts) {
      expect(text.includes('"agent-status"'), `${rel} calls herdr wait agent-status`).toBe(false);
    }
  });
});

describe("eval arms are reproducible", () => {
  it("pins the exact files the full arm injects", () => {
    expect(ARM_SOURCES.full).toHaveLength(3);
    for (const path of ARM_SOURCES.full) {
      expect(() => readFileSync(path, "utf8")).not.toThrow();
    }
  });

  it("gives every arm identical tool framing so only context differs", () => {
    for (const arm of ["helpOnly", "minimal", "full"] as const) {
      expect(renderArmContext(arm)).toContain("herdr");
    }
    expect(renderArmContext("helpOnly")).not.toContain("Known pitfalls");
    expect(renderArmContext("minimal")).toContain("alternate screen");
    expect(renderArmContext("full")).toContain("Known pitfalls");
  });

  it("keeps the minimal arm to semantics rather than syntax", () => {
    // It must teach state meaning without restating discoverable flag tables.
    expect(MINIMAL_SKILL_TEXT).toContain("CLI reads do NOT mark a tab as seen");
    expect(MINIMAL_SKILL_TEXT).toContain("root_pane");
    expect(MINIMAL_SKILL_TEXT.split("\n").length).toBeLessThan(45);
  });
});
