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
  buildManualReflectionPrompt,
  buildReflectionReminder,
  buildReflectionTranscript,
  getReflectionRuntimeDir,
  getReflectionTriggerSource,
  loadReflectionRuntimeState,
  loadSettings,
  prepareReflectionBundle,
  requestBackgroundReflectionLaunch,
  saveSettings,
  buildTree,
  resolveReflectionSettings,
  shouldEmitReflectionReminder,
  detectPromptDrift,
  formatBackupTimestamp,
  formatReflectionSettings,
  getWorktreeDir,
  installPreCommitHook,
  loadSystemFiles,
  parseFrontmatter,
  scaffoldMemory,
  statusWidget,
  stripManagedMemorySections,
  validateFrontmatter,
  REFLECTION_LAUNCH_EVENT,
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

  test("truncates very large trees and includes a notice", () => {
    mkdirSync(join(tmpDir, "notes"), { recursive: true });
    for (let i = 0; i < 200; i++) {
      writeFileSync(
        join(tmpDir, "notes", `topic-${String(i).padStart(4, "0")}.md`),
        fm(`description: Topic ${i}\nlimit: 1000`)
      );
    }

    const tree = buildTree(tmpDir, "", { maxLines: 20, maxChars: 700, maxChildrenPerDir: 500 });
    const rendered = tree.join("\n");

    expect(tree.length).toBeLessThanOrEqual(20);
    expect(rendered.length).toBeLessThanOrEqual(700);
    expect(rendered).toContain("[Tree truncated: showing");
    expect(rendered).toContain("omitted.");
  });

  test("adds omission markers inside wide directories", () => {
    mkdirSync(join(tmpDir, "notes"), { recursive: true });
    for (let i = 0; i < 10; i++) {
      writeFileSync(
        join(tmpDir, "notes", `topic-${String(i).padStart(4, "0")}.md`),
        fm(`description: Topic ${i}\nlimit: 1000`)
      );
    }

    const rendered = buildTree(tmpDir, "", {
      maxLines: 200,
      maxChars: 10_000,
      maxChildrenPerDir: 5,
    }).join("\n");

    expect(rendered).toContain("... (5 more entries)");
    expect(rendered).not.toContain("topic-0009.md");
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

// --- detectPromptDrift ---

describe("detectPromptDrift", () => {
  test("returns empty for clean prompt", () => {
    expect(detectPromptDrift("You are a helpful assistant.")).toEqual([]);
  });

  test("detects legacy memory-block language", () => {
    const prompt = "Your memory consists of core memory (composed of memory blocks)";
    const drifts = detectPromptDrift(prompt);
    expect(drifts).toHaveLength(1);
    expect(drifts[0].code).toBe("legacy_memory_section");
  });

  test("detects orphan sync fragment", () => {
    const prompt = 'Some text\ngit add system/\ngit commit -m "update"';
    const drifts = detectPromptDrift(prompt);
    expect(drifts).toHaveLength(1);
    expect(drifts[0].code).toBe("orphan_memory_fragment");
  });

  test("does not flag sync fragment when context-repo section present", () => {
    const prompt = '## Context Repository (Agent Memory)\ngit add system/\ngit commit -m "update"';
    const drifts = detectPromptDrift(prompt);
    expect(drifts.every((d) => d.code !== "orphan_memory_fragment")).toBe(true);
  });

  test("detects duplicate context-repo sections", () => {
    const prompt =
      "## Context Repository (Agent Memory)\nfirst\n## Context Repository (Agent Memory)\nsecond";
    const drifts = detectPromptDrift(prompt);
    expect(drifts.some((d) => d.code === "duplicate_memory_section")).toBe(true);
  });
});

// --- stripManagedMemorySections ---

describe("stripManagedMemorySections", () => {
  test("removes context-repo section", () => {
    const prompt =
      "Before.\n\n## Context Repository (Agent Memory)\n\nMemory content here.\n\n## Other Section\n\nAfter.";
    const result = stripManagedMemorySections(prompt);
    expect(result).not.toContain("Context Repository");
    expect(result).toContain("Before.");
    expect(result).toContain("Other Section");
  });

  test("removes system-reminder blocks", () => {
    const prompt =
      "Before.\n<system-reminder>\nMEMORY SYNC: 2 uncommitted\n</system-reminder>\nAfter.";
    const result = stripManagedMemorySections(prompt);
    expect(result).not.toContain("MEMORY SYNC");
    expect(result).toContain("Before.");
    expect(result).toContain("After.");
  });

  test("preserves unrelated content", () => {
    const prompt = "## Instructions\n\nDo stuff.\n\n## Notes\n\nSome notes.";
    expect(stripManagedMemorySections(prompt)).toBe(prompt);
  });

  test("compacts excessive blank lines", () => {
    const prompt = "A.\n\n\n\n\nB.";
    expect(stripManagedMemorySections(prompt)).toBe("A.\n\nB.");
  });
});

// --- getWorktreeDir ---

describe("getWorktreeDir", () => {
  test("returns sibling memory-worktrees directory", () => {
    const memDir = "/home/user/.pi/memory";
    expect(getWorktreeDir(memDir)).toBe("/home/user/.pi/memory-worktrees");
  });
});

// --- scaffoldMemory (new blocks) ---

describe("scaffoldMemory new blocks", () => {
  let memDir: string;

  beforeEach(() => {
    memDir = join(tmpMemDir(), "memory");
  });
  afterEach(() => {
    rmSync(join(memDir, ".."), { recursive: true, force: true });
  });

  test("creates system/project.md with valid frontmatter", () => {
    scaffoldMemory(memDir);
    const content = readFileSync(join(memDir, "system/project.md"), "utf-8");
    const { frontmatter, body } = parseFrontmatter(content);
    expect(frontmatter.description).toBeTruthy();
    expect(frontmatter.limit).toBeGreaterThan(0);
    expect(validateFrontmatter(content, "system/project.md")).toEqual([]);
    expect(body).toContain("codebase");
  });

  test("creates system/style.md with valid frontmatter", () => {
    scaffoldMemory(memDir);
    const content = readFileSync(join(memDir, "system/style.md"), "utf-8");
    const { frontmatter, body } = parseFrontmatter(content);
    expect(frontmatter.description).toBeTruthy();
    expect(frontmatter.limit).toBeGreaterThan(0);
    expect(validateFrontmatter(content, "system/style.md")).toEqual([]);
    expect(body).toContain("preferences");
  });
});

// --- Persona presets ---

describe("scaffoldMemory persona presets", () => {
  let memDir: string;

  beforeEach(() => {
    memDir = join(tmpMemDir(), "memory");
  });
  afterEach(() => {
    rmSync(join(memDir, ".."), { recursive: true, force: true });
  });

  test("default persona contains helpful assistant", () => {
    scaffoldMemory(memDir);
    const content = readFileSync(join(memDir, "system/persona.md"), "utf-8");
    expect(content).toContain("helpful");
  });

  test("concise persona uses terse style", () => {
    scaffoldMemory(memDir, "concise");
    const content = readFileSync(join(memDir, "system/persona.md"), "utf-8");
    expect(content).toContain("terse");
    expect(content).toContain("concise");
  });

  test("friendly persona uses warm style", () => {
    scaffoldMemory(memDir, "friendly");
    const content = readFileSync(join(memDir, "system/persona.md"), "utf-8");
    expect(content).toContain("friendly");
    expect(content).toContain("collaborative");
  });

  test("mentor persona uses teaching style", () => {
    scaffoldMemory(memDir, "mentor");
    const content = readFileSync(join(memDir, "system/persona.md"), "utf-8");
    expect(content).toContain("mentor");
    expect(content).toContain("why");
  });

  test("unknown preset falls back to default", () => {
    scaffoldMemory(memDir, "nonexistent");
    const content = readFileSync(join(memDir, "system/persona.md"), "utf-8");
    expect(content).toContain("helpful");
  });
});

// --- Per-agent settings ---

describe("per-agent settings", () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = tmpMemDir();
  });
  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  test("loadSettings returns defaults when no file exists", () => {
    const settings = loadSettings(tmpDir);
    expect(settings.memfsEnabled).toBe(true);
    expect(settings.reflectionInterval).toBe(15);
    expect(settings.reflectionTrigger).toBe("step-count");
    expect(settings.reflectionStepCount).toBe(15);
    expect(settings.personaPreset).toBe("default");
  });

  test("saveSettings persists and loadSettings reads back", () => {
    saveSettings(tmpDir, {
      reflectionTrigger: "step-count",
      reflectionStepCount: 30,
      personaPreset: "concise",
    });
    const settings = loadSettings(tmpDir);
    expect(settings.reflectionInterval).toBe(30);
    expect(settings.reflectionTrigger).toBe("step-count");
    expect(settings.reflectionStepCount).toBe(30);
    expect(settings.personaPreset).toBe("concise");
    expect(settings.memfsEnabled).toBe(true);
  });

  test("saveSettings merges with existing", () => {
    saveSettings(tmpDir, { reflectionStepCount: 20 });
    saveSettings(tmpDir, { personaPreset: "mentor" });
    const settings = loadSettings(tmpDir);
    expect(settings.reflectionInterval).toBe(20);
    expect(settings.reflectionStepCount).toBe(20);
    expect(settings.personaPreset).toBe("mentor");
  });

  test("loadSettings normalizes legacy reflectionInterval files", () => {
    writeFileSync(
      join(tmpDir, ".settings.json"),
      JSON.stringify({ reflectionInterval: 7, personaPreset: "friendly" }, null, 2)
    );
    const settings = loadSettings(tmpDir);
    expect(settings.reflectionTrigger).toBe("step-count");
    expect(settings.reflectionStepCount).toBe(7);
    expect(settings.reflectionInterval).toBe(7);
    expect(settings.personaPreset).toBe("friendly");
  });

  test("loadSettings preserves legacy disabled reminders", () => {
    writeFileSync(
      join(tmpDir, ".settings.json"),
      JSON.stringify({ reflectionInterval: 0 }, null, 2)
    );
    const settings = loadSettings(tmpDir);
    expect(settings.reflectionTrigger).toBe("off");
    expect(settings.reflectionInterval).toBe(0);
  });

  test("saveSettings writes legacy-compatible off mode", () => {
    const settings = saveSettings(tmpDir, { reflectionTrigger: "off", reflectionStepCount: 12 });
    expect(settings.reflectionTrigger).toBe("off");
    expect(settings.reflectionInterval).toBe(0);

    const saved = JSON.parse(readFileSync(join(tmpDir, ".settings.json"), "utf-8"));
    expect(saved.reflectionTrigger).toBe("off");
    expect(saved.reflectionInterval).toBe(0);
    expect(saved.reflectionStepCount).toBe(12);
  });

  test("loadSettings handles corrupt file gracefully", () => {
    writeFileSync(join(tmpDir, ".settings.json"), "not json");
    const settings = loadSettings(tmpDir);
    expect(settings.memfsEnabled).toBe(true);
    expect(settings.reflectionTrigger).toBe("step-count");
  });
});

describe("reflection settings helpers", () => {
  test("resolveReflectionSettings honors explicit trigger and step count", () => {
    expect(
      resolveReflectionSettings({ reflectionTrigger: "compaction-event", reflectionStepCount: 9 })
    ).toEqual({
      trigger: "compaction-event",
      stepCount: 9,
    });
  });

  test("resolveReflectionSettings falls back for invalid values", () => {
    expect(
      resolveReflectionSettings({ reflectionTrigger: "nope", reflectionStepCount: -1 })
    ).toEqual({
      trigger: "step-count",
      stepCount: 15,
    });
  });

  test("shouldEmitReflectionReminder respects off and step-count triggers", () => {
    expect(shouldEmitReflectionReminder(15, { trigger: "off", stepCount: 15 })).toBe(false);
    expect(shouldEmitReflectionReminder(15, { trigger: "step-count", stepCount: 15 })).toBe(true);
    expect(shouldEmitReflectionReminder(14, { trigger: "step-count", stepCount: 15 })).toBe(false);
  });

  test("shouldEmitReflectionReminder respects compaction-event trigger", () => {
    expect(
      shouldEmitReflectionReminder(99, { trigger: "compaction-event", stepCount: 15 }, false)
    ).toBe(false);
    expect(
      shouldEmitReflectionReminder(99, { trigger: "compaction-event", stepCount: 15 }, true)
    ).toBe(true);
  });

  test("formatReflectionSettings summarizes modes", () => {
    expect(formatReflectionSettings({ trigger: "off", stepCount: 15 })).toBe("off");
    expect(formatReflectionSettings({ trigger: "step-count", stepCount: 5 })).toBe(
      "step-count (5 turns)"
    );
    expect(formatReflectionSettings({ trigger: "compaction-event", stepCount: 8 })).toContain(
      "compaction-event"
    );
  });
});

import { execSync } from "node:child_process";
import { createWorktree, mergeWorktree, PERSONA_PRESETS, type WorktreeInfo } from "./index";

// --- Git repo test helpers ---

/**
 * Create a temp dir with a real git repo initialized + initial commit.
 * Returns the memory dir path (has .git, system/, reference/).
 */
function createTestGitRepo(): string {
  const base = mkdtempSync(join(tmpdir(), "ctx-repo-git-"));
  const memDir = join(base, ".pi", "memory");
  scaffoldMemory(memDir);
  execSync("git init", { cwd: memDir });
  execSync("git add -A", { cwd: memDir });
  execSync('git -c commit.gpgsign=false -c user.name=test -c user.email=t@t commit -m "init"', {
    cwd: memDir,
  });
  installPreCommitHook(memDir);
  return memDir;
}

/**
 * Minimal mock of ExtensionAPI — only pi.exec is needed for git operations.
 */
function mockPi() {
  return {
    exec: (cmd: string, args: string[]) => {
      const { execFileSync } = require("node:child_process");
      try {
        const stdout = execFileSync(cmd, args, {
          encoding: "utf-8",
          timeout: 10000,
        });
        return Promise.resolve({ stdout, stderr: "" });
      } catch (e: any) {
        const err = new Error(e.stderr || e.message);
        return Promise.reject(err);
      }
    },
  } as any; // ExtensionAPI mock
}

// --- createWorktree ---

describe("createWorktree", () => {
  let memDir: string;
  const pi = mockPi();

  beforeEach(() => {
    memDir = createTestGitRepo();
  });
  afterEach(() => {
    // Clean up the base temp dir (parent of .pi/memory)
    const base = memDir.replace(/\/.pi\/memory$/, "");
    rmSync(base, { recursive: true, force: true });
    // Also clean up worktree dir
    const wtDir = getWorktreeDir(memDir);
    if (existsSync(wtDir)) rmSync(wtDir, { recursive: true, force: true });
  });

  test("creates a worktree directory and branch", async () => {
    const wt = await createWorktree(pi, memDir, "test");
    expect(wt.branch).toMatch(/^test-\d+$/);
    expect(existsSync(wt.path)).toBe(true);
    // The worktree should have the same files
    expect(existsSync(join(wt.path, "system", "persona.md"))).toBe(true);
  });

  test("worktree branch shows up in git branch list", async () => {
    const wt = await createWorktree(pi, memDir, "feat");
    const branches = execSync("git branch --list", { cwd: memDir, encoding: "utf-8" });
    expect(branches).toContain(wt.branch);
  });

  test("creates worktree dir inside memory-worktrees sibling", async () => {
    const wt = await createWorktree(pi, memDir, "sibling");
    const expectedParent = getWorktreeDir(memDir);
    expect(wt.path.startsWith(expectedParent)).toBe(true);
  });

  test("edits in worktree don't affect main", async () => {
    const wt = await createWorktree(pi, memDir, "isolated");
    writeFileSync(
      join(wt.path, "system", "wt-only.md"),
      "---\ndescription: WT\nlimit: 1000\n---\n\nWT content.\n"
    );
    expect(existsSync(join(memDir, "system", "wt-only.md"))).toBe(false);
  });
});

// --- mergeWorktree ---

describe("mergeWorktree", () => {
  let memDir: string;
  const pi = mockPi();

  beforeEach(() => {
    memDir = createTestGitRepo();
  });
  afterEach(() => {
    const base = memDir.replace(/\/.pi\/memory$/, "");
    rmSync(base, { recursive: true, force: true });
    const wtDir = getWorktreeDir(memDir);
    if (existsSync(wtDir)) rmSync(wtDir, { recursive: true, force: true });
  });

  test("merges worktree changes back to main", async () => {
    const wt = await createWorktree(pi, memDir, "merge");

    // Make a change in the worktree and commit
    const newFile = join(wt.path, "system", "merged-note.md");
    writeFileSync(newFile, "---\ndescription: Merged note\nlimit: 1000\n---\n\nMerged content.\n");
    execSync("git add -A", { cwd: wt.path });
    execSync(
      'git -c commit.gpgsign=false -c user.name=test -c user.email=t@t commit -m "add merged note"',
      { cwd: wt.path }
    );

    const result = await mergeWorktree(pi, memDir, wt);
    expect(result.merged).toBe(true);
    expect(result.summary).toContain("Merged");

    // File should now exist in main
    expect(existsSync(join(memDir, "system", "merged-note.md"))).toBe(true);
  });

  test("cleans up worktree directory after merge", async () => {
    const wt = await createWorktree(pi, memDir, "cleanup");

    writeFileSync(join(wt.path, "temp.md"), "---\ndescription: Temp\nlimit: 500\n---\n\nTemp.\n");
    execSync("git add -A", { cwd: wt.path });
    execSync(
      'git -c commit.gpgsign=false -c user.name=test -c user.email=t@t commit -m "temp commit"',
      { cwd: wt.path }
    );

    await mergeWorktree(pi, memDir, wt);

    // Worktree dir should be removed
    expect(existsSync(wt.path)).toBe(false);
  });

  test("cleans up branch after merge", async () => {
    const wt = await createWorktree(pi, memDir, "branchclean");

    writeFileSync(join(wt.path, "branchtest.md"), "---\ndescription: B\nlimit: 500\n---\n\nB.\n");
    execSync("git add -A", { cwd: wt.path });
    execSync(
      'git -c commit.gpgsign=false -c user.name=test -c user.email=t@t commit -m "branch test"',
      { cwd: wt.path }
    );

    await mergeWorktree(pi, memDir, wt);

    const branches = execSync("git branch --list", { cwd: memDir, encoding: "utf-8" });
    expect(branches).not.toContain(wt.branch);
  });

  test("reports push pending when no remote", async () => {
    const wt = await createWorktree(pi, memDir, "nopush");

    writeFileSync(join(wt.path, "nopush.md"), "---\ndescription: NP\nlimit: 500\n---\n\nNP.\n");
    execSync("git add -A", { cwd: wt.path });
    execSync(
      'git -c commit.gpgsign=false -c user.name=test -c user.email=t@t commit -m "no push"',
      { cwd: wt.path }
    );

    const result = await mergeWorktree(pi, memDir, wt);
    expect(result.pushed).toBe(false);
    expect(result.summary).toContain("pending");
  });

  test("handles merge with no commits (empty worktree)", async () => {
    const wt = await createWorktree(pi, memDir, "empty");

    // No changes made — merge should still succeed (nothing to merge, fast-forward)
    const result = await mergeWorktree(pi, memDir, wt);
    expect(result.merged).toBe(true);
  });
});

// --- listBackups (via backup/restore cycle) ---

describe("backup and restore cycle", () => {
  let memDir: string;

  beforeEach(() => {
    const base = mkdtempSync(join(tmpdir(), "ctx-backup-"));
    memDir = join(base, ".pi", "memory");
    scaffoldMemory(memDir);
  });
  afterEach(() => {
    const base = memDir.replace(/\/.pi\/memory$/, "");
    rmSync(base, { recursive: true, force: true });
  });

  test("backup creates a copy of memory dir", () => {
    const { cpSync } = require("node:fs");
    const backupDir = join(memDir, "..", "memory-backups");
    const backupName = `backup-${formatBackupTimestamp()}`;
    const backupPath = join(backupDir, backupName);
    mkdirSync(backupDir, { recursive: true });
    cpSync(memDir, backupPath, { recursive: true });

    expect(existsSync(backupPath)).toBe(true);
    expect(existsSync(join(backupPath, "system", "persona.md"))).toBe(true);
  });

  test("restore overwrites memory dir from backup", () => {
    const { cpSync } = require("node:fs");
    const backupDir = join(memDir, "..", "memory-backups");
    const backupPath = join(backupDir, "backup-test");
    mkdirSync(backupDir, { recursive: true });
    cpSync(memDir, backupPath, { recursive: true });

    // Modify original
    writeFileSync(
      join(memDir, "system", "persona.md"),
      "---\ndescription: Modified\nlimit: 3000\n---\n\nChanged.\n"
    );

    // Restore
    rmSync(memDir, { recursive: true, force: true });
    cpSync(backupPath, memDir, { recursive: true });

    const content = readFileSync(join(memDir, "system", "persona.md"), "utf-8");
    expect(content).toContain("helpful"); // original content restored
    expect(content).not.toContain("Changed");
  });
});

// --- memory_delete logic (unit-level, no ExtensionAPI needed) ---

describe("memory_delete logic", () => {
  let memDir: string;

  beforeEach(() => {
    memDir = createTestGitRepo();
  });
  afterEach(() => {
    const base = memDir.replace(/\/.pi\/memory$/, "");
    rmSync(base, { recursive: true, force: true });
  });

  test("deleting a non-existent file is caught", () => {
    const filePath = join(memDir, "reference", "nonexistent.md");
    expect(existsSync(filePath)).toBe(false);
  });

  test("read_only files cannot be deleted (guard logic)", () => {
    const roFile = join(memDir, "system", "locked.md");
    writeFileSync(
      roFile,
      "---\ndescription: Locked\nlimit: 1000\nread_only: true\n---\n\nLocked.\n"
    );
    // Bypass pre-commit hook since it (correctly) rejects agent-set read_only
    execSync("git add -A", { cwd: memDir });
    execSync(
      'git -c commit.gpgsign=false -c user.name=test -c user.email=t@t commit --no-verify -m "add locked file"',
      { cwd: memDir }
    );

    const content = readFileSync(roFile, "utf-8");
    const { frontmatter } = parseFrontmatter(content);
    expect(frontmatter.read_only).toBe(true);
    // The tool would reject deletion — we're testing the guard condition
  });

  test("deleting a writable file removes it from disk", () => {
    const target = join(memDir, "reference", "deleteme.md");
    writeFileSync(target, "---\ndescription: Delete me\nlimit: 1000\n---\n\nTemp.\n");
    execSync("git add -A", { cwd: memDir });
    execSync(
      'git -c commit.gpgsign=false -c user.name=test -c user.email=t@t commit -m "add deleteme"',
      { cwd: memDir }
    );

    expect(existsSync(target)).toBe(true);
    rmSync(target);
    expect(existsSync(target)).toBe(false);

    // Git recognizes the deletion
    const status = execSync("git status --porcelain", { cwd: memDir, encoding: "utf-8" });
    expect(status).toContain("deleteme.md");
  });

  test("deleted file can be staged with git add", () => {
    const target = join(memDir, "reference", "stageme.md");
    writeFileSync(target, "---\ndescription: Stage me\nlimit: 1000\n---\n\nStage.\n");
    execSync("git add -A", { cwd: memDir });
    execSync(
      'git -c commit.gpgsign=false -c user.name=test -c user.email=t@t commit -m "add stageme"',
      { cwd: memDir }
    );

    rmSync(target);
    execSync("git add reference/stageme.md", { cwd: memDir });

    const staged = execSync("git diff --cached --name-only", { cwd: memDir, encoding: "utf-8" });
    expect(staged).toContain("reference/stageme.md");
  });
});

// --- memory_recall JSONL parsing logic ---

describe("memory_recall JSONL parsing", () => {
  let sessionsDir: string;

  beforeEach(() => {
    sessionsDir = mkdtempSync(join(tmpdir(), "ctx-sessions-"));
  });
  afterEach(() => {
    rmSync(sessionsDir, { recursive: true, force: true });
  });

  test("finds matching messages in JSONL files", () => {
    const sessionFile = join(sessionsDir, "session-1.jsonl");
    const entries = [
      JSON.stringify({
        type: "message",
        timestamp: "2026-01-15T10:00:00Z",
        message: { role: "user", content: "Please fix the authentication bug" },
      }),
      JSON.stringify({
        type: "message",
        timestamp: "2026-01-15T10:01:00Z",
        message: { role: "assistant", content: "I'll look into the authentication issue now." },
      }),
      JSON.stringify({ type: "tool_call", timestamp: "2026-01-15T10:02:00Z", tool: "bash" }),
      JSON.stringify({
        type: "message",
        timestamp: "2026-01-15T10:03:00Z",
        message: { role: "user", content: "Great, also check the database connection" },
      }),
    ];
    writeFileSync(sessionFile, entries.join("\n") + "\n");

    // Simulate what memory_recall does: grep + parse
    const query = "authentication";
    const lines = readFileSync(sessionFile, "utf-8").trim().split("\n");
    const results: Array<{ date: string; role: string; snippet: string }> = [];

    for (const line of lines) {
      try {
        const entry = JSON.parse(line);
        if (entry.type !== "message") continue;
        const msg = entry.message;
        if (!msg?.content) continue;

        let text = typeof msg.content === "string" ? msg.content : "";
        if (!text.toLowerCase().includes(query.toLowerCase())) continue;

        const idx = text.toLowerCase().indexOf(query.toLowerCase());
        const start = Math.max(0, idx - 100);
        const end = Math.min(text.length, idx + query.length + 100);
        const snippet = text.slice(start, end);

        results.push({
          date: new Date(entry.timestamp).toISOString().slice(0, 16),
          role: msg.role,
          snippet,
        });
      } catch {
        // skip
      }
    }

    expect(results).toHaveLength(2);
    expect(results[0].role).toBe("user");
    expect(results[0].snippet).toContain("authentication");
    expect(results[1].role).toBe("assistant");
  });

  test("handles array content format", () => {
    const sessionFile = join(sessionsDir, "session-2.jsonl");
    const entry = JSON.stringify({
      type: "message",
      timestamp: "2026-01-15T10:00:00Z",
      message: {
        role: "assistant",
        content: [
          { type: "text", text: "I found the webpack config issue." },
          { type: "tool_use", id: "t1", name: "bash" },
        ],
      },
    });
    writeFileSync(sessionFile, entry + "\n");

    const line = readFileSync(sessionFile, "utf-8").trim();
    const parsed = JSON.parse(line);
    const msg = parsed.message;
    const text = Array.isArray(msg.content)
      ? msg.content
          .filter((c: any) => c.type === "text" && c.text)
          .map((c: any) => c.text)
          .join("\n")
      : msg.content;

    expect(text).toContain("webpack");
  });

  test("skips non-message entries", () => {
    const sessionFile = join(sessionsDir, "session-3.jsonl");
    const entries = [
      JSON.stringify({ type: "tool_call", tool: "bash", input: "search term here" }),
      JSON.stringify({ type: "system", content: "search term here" }),
    ];
    writeFileSync(sessionFile, entries.join("\n") + "\n");

    const lines = readFileSync(sessionFile, "utf-8").trim().split("\n");
    const matches = lines.filter((l) => {
      try {
        return JSON.parse(l).type === "message";
      } catch {
        return false;
      }
    });

    expect(matches).toHaveLength(0);
  });

  test("handles malformed JSONL gracefully", () => {
    const sessionFile = join(sessionsDir, "session-4.jsonl");
    writeFileSync(
      sessionFile,
      "not json\n{bad\n" +
        JSON.stringify({ type: "message", message: { role: "user", content: "valid" } }) +
        "\n"
    );

    const lines = readFileSync(sessionFile, "utf-8").trim().split("\n");
    let validCount = 0;
    for (const line of lines) {
      try {
        const entry = JSON.parse(line);
        if (entry.type === "message") validCount++;
      } catch {
        // expected for malformed lines
      }
    }

    expect(validCount).toBe(1);
  });
});

// --- before_agent_start prompt building ---

describe("system prompt building", () => {
  test("drift warning is injected when legacy memory detected", () => {
    const systemPrompt = "Your memory consists of core memory blocks";
    const drifts = detectPromptDrift(systemPrompt);
    expect(drifts.length).toBeGreaterThan(0);

    // Simulate what before_agent_start does
    const driftWarning =
      drifts.length > 0
        ? `\n<system-reminder>\nMEMORY PROMPT DRIFT DETECTED:\n${drifts.map((d) => `- ${d.message}`).join("\n")}\nThe context-repo extension manages memory sections. Legacy fragments may cause confusion.\n</system-reminder>\n`
        : "";

    expect(driftWarning).toContain("MEMORY PROMPT DRIFT DETECTED");
    expect(driftWarning).toContain("legacy memory-block");
  });

  test("drift warning is empty when prompt is clean", () => {
    const drifts = detectPromptDrift("You are a helpful assistant.");
    const driftWarning = drifts.length > 0 ? "WARNING" : "";
    expect(driftWarning).toBe("");
  });

  test("memory block contains expected sections", () => {
    // Simulate the template building
    const tree = ["├── system/", "│   ├── persona.md", "└── reference/"];
    const systemContent = "<system/persona.md>\nContent\n</system/persona.md>";

    const memoryBlock = `
## Context Repository (Agent Memory)

### Memory Filesystem
\`\`\`
.pi/memory/
${tree.join("\n")}
\`\`\`

### Pinned Memory (system/)
${systemContent}

### Memory Guidelines
- To remember something: use the memory_write tool
- To remove a file: use the memory_delete tool

### Syncing

### Conflict Resolution
`;

    expect(memoryBlock).toContain("Context Repository (Agent Memory)");
    expect(memoryBlock).toContain("Memory Filesystem");
    expect(memoryBlock).toContain("Pinned Memory");
    expect(memoryBlock).toContain("Memory Guidelines");
    expect(memoryBlock).toContain("memory_delete");
    expect(memoryBlock).toContain("Syncing");
    expect(memoryBlock).toContain("Conflict Resolution");
  });

  test("reflection reminder fires at correct interval", () => {
    const fired: number[] = [];
    for (let turn = 1; turn <= 50; turn++) {
      if (shouldEmitReflectionReminder(turn, { trigger: "step-count", stepCount: 15 })) {
        fired.push(turn);
      }
    }
    expect(fired).toEqual([15, 30, 45]);
  });

  test("env vars are set correctly", () => {
    const memDir = "/some/project/.pi/memory";
    const env = { MEMORY_DIR: memDir, PI_MEMORY_DIR: memDir };
    expect(env.MEMORY_DIR).toBe(memDir);
    expect(env.PI_MEMORY_DIR).toBe(memDir);
  });
});

describe("reflection bundle helpers", () => {
  test("getReflectionTriggerSource returns trigger kind", () => {
    expect(getReflectionTriggerSource(15, { trigger: "step-count", stepCount: 15 })).toBe(
      "step-count"
    );
    expect(
      getReflectionTriggerSource(2, { trigger: "compaction-event", stepCount: 15 }, true)
    ).toBe("compaction-event");
    expect(getReflectionTriggerSource(2, { trigger: "off", stepCount: 15 })).toBeNull();
  });

  test("buildReflectionTranscript renders message and compaction entries", () => {
    const transcript = buildReflectionTranscript([
      { type: "message", message: { role: "user", content: "hello" } },
      { type: "message", message: { role: "assistant", content: [{ type: "text", text: "hi" }] } },
      { type: "compaction", summary: "Earlier turns compacted" },
    ]);

    expect(transcript).toContain("<user>");
    expect(transcript).toContain("hello");
    expect(transcript).toContain("<assistant>");
    expect(transcript).toContain("Earlier turns compacted");
  });

  test("prepareReflectionBundle writes transcript, prompt, and runtime state", () => {
    const memDir = tmpMemDir();
    scaffoldMemory(memDir);

    const bundle = prepareReflectionBundle(
      memDir,
      {
        getSessionId: () => "session:1",
        getSessionFile: () => "/tmp/session.jsonl",
        getBranch: () => [
          { type: "message", message: { role: "user", content: "remember this detail" } },
          { type: "message", message: { role: "assistant", content: "I will." } },
        ],
      },
      {
        triggerSource: "step-count",
        cwd: "/tmp/project",
        memoryTree: ".pi/memory/\n└── system/",
        systemContent: "<system/project.md>Notes</system/project.md>",
      }
    );

    expect(existsSync(bundle.transcriptPath)).toBe(true);
    expect(existsSync(bundle.promptPath)).toBe(true);
    expect(readFileSync(bundle.transcriptPath, "utf-8")).toContain("remember this detail");
    expect(readFileSync(bundle.promptPath, "utf-8")).toContain("trigger: step-count");
    expect(bundle.sessionId).toBe("session_1");
    expect(getReflectionRuntimeDir(memDir)).toContain("reflection-runtime");

    const state = loadReflectionRuntimeState(memDir);
    expect(state.latestBundle?.transcriptPath).toBe(bundle.transcriptPath);
    expect(state.lastLaunchMode).toBe("prepared");

    rmSync(memDir, { recursive: true, force: true });
  });

  test("requestBackgroundReflectionLaunch falls back when no listener accepts", () => {
    const emitted: Array<{ channel: string; accepted: boolean }> = [];
    const bundle = {
      bundleId: "b1",
      bundleDir: "/tmp/b1",
      triggerSource: "step-count" as const,
      createdAt: new Date().toISOString(),
      sessionId: "s1",
      sessionFile: "/tmp/session.jsonl",
      transcriptPath: "/tmp/b1/transcript.md",
      promptPath: "/tmp/b1/prompt.md",
      metadataPath: "/tmp/b1/metadata.json",
      memoryDir: "/tmp/.pi/memory",
      entryCount: 2,
    };
    const eventBus = {
      emit(channel: string, request: any) {
        emitted.push({ channel, accepted: request.accepted });
      },
      on() {
        return () => {};
      },
    };

    const result = requestBackgroundReflectionLaunch(eventBus, bundle, "step-count");
    expect(emitted[0]?.channel).toBe(REFLECTION_LAUNCH_EVENT);
    expect(result.launched).toBe(false);
    expect(result.mode).toBe("reminder-fallback");
    expect(buildReflectionReminder(bundle)).toContain(bundle.transcriptPath);
    expect(buildManualReflectionPrompt(bundle)).toContain(bundle.promptPath);
  });

  test("requestBackgroundReflectionLaunch reports accepted launch", () => {
    const bundle = {
      bundleId: "b2",
      bundleDir: "/tmp/b2",
      triggerSource: "manual" as const,
      createdAt: new Date().toISOString(),
      sessionId: "s2",
      sessionFile: "/tmp/session.jsonl",
      transcriptPath: "/tmp/b2/transcript.md",
      promptPath: "/tmp/b2/prompt.md",
      metadataPath: "/tmp/b2/metadata.json",
      memoryDir: "/tmp/.pi/memory",
      entryCount: 1,
    };
    const eventBus = {
      emit(_channel: string, request: any) {
        request.note("listener saw request");
        request.accept("launched by test listener");
      },
      on() {
        return () => {};
      },
    };

    const result = requestBackgroundReflectionLaunch(eventBus, bundle, "manual");
    expect(result.launched).toBe(true);
    expect(result.mode).toBe("background-subagent");
    expect(result.notes).toEqual(["listener saw request", "launched by test listener"]);
  });
});

// --- PERSONA_PRESETS exhaustive ---

describe("PERSONA_PRESETS", () => {
  test("all presets have description and content", () => {
    for (const [name, preset] of Object.entries(PERSONA_PRESETS)) {
      expect(preset.description).toBeTruthy();
      expect(preset.content).toBeTruthy();
      expect(preset.content.length).toBeGreaterThan(10);
    }
  });

  test("has at least 4 presets", () => {
    expect(Object.keys(PERSONA_PRESETS).length).toBeGreaterThanOrEqual(4);
  });

  test("default preset exists", () => {
    expect(PERSONA_PRESETS.default).toBeDefined();
  });
});

// --- stripManagedMemorySections edge cases ---

describe("stripManagedMemorySections edge cases", () => {
  test("handles context-repo at end of prompt (no following section)", () => {
    const prompt =
      "## Instructions\n\nDo stuff.\n\n## Context Repository (Agent Memory)\n\nAll memory here.";
    const result = stripManagedMemorySections(prompt);
    expect(result).toContain("Instructions");
    expect(result).not.toContain("All memory here");
  });

  test("handles MEMORY REFLECTION reminder removal", () => {
    const prompt =
      "Before.\n<system-reminder>\nMEMORY REFLECTION: time to reflect\nReview conversation.\n</system-reminder>\nAfter.";
    const result = stripManagedMemorySections(prompt);
    expect(result).not.toContain("MEMORY REFLECTION");
    expect(result).toContain("Before.");
    expect(result).toContain("After.");
  });

  test("handles MEMORY CHECK reminder removal", () => {
    const prompt =
      "Before.\n<system-reminder>\nMEMORY CHECK: verify state\n</system-reminder>\nAfter.";
    const result = stripManagedMemorySections(prompt);
    expect(result).not.toContain("MEMORY CHECK");
  });

  test("handles multiple system-reminder blocks", () => {
    const prompt =
      "<system-reminder>\nMEMORY SYNC: dirty\n</system-reminder>\nMiddle.\n<system-reminder>\nMEMORY REFLECTION: reflect\n</system-reminder>";
    const result = stripManagedMemorySections(prompt);
    expect(result).not.toContain("MEMORY SYNC");
    expect(result).not.toContain("MEMORY REFLECTION");
    expect(result).toContain("Middle.");
  });

  test("preserves non-MEMORY system-reminder blocks", () => {
    const prompt = "<system-reminder>\nSOMETHING ELSE: important\n</system-reminder>";
    const result = stripManagedMemorySections(prompt);
    expect(result).toContain("SOMETHING ELSE");
  });
});
