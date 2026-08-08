import { spawnSync } from "node:child_process";
import { copyFileSync, mkdtempSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, test } from "vitest";
import { buildIndex, resolveEntry } from "../src/project.ts";
import { buildTree, type BuildOptions } from "../src/tree.ts";
import { diffTrees } from "../src/diff.ts";
import { render, toRenderNode } from "../src/render.ts";

const OPTS: BuildOptions = { maxDepth: 6, groupBranches: true, showArgs: false };
const HERE = fileURLToPath(new URL(".", import.meta.url));

function runCli(...args: string[]) {
  const result = spawnSync("bun", ["run", join(HERE, "..", "src", "cli.ts"), ...args], {
    encoding: "utf8",
  });
  return { exitCode: result.status, stdout: result.stdout, stderr: result.stderr };
}

function git(cwd: string, ...args: string[]): void {
  const result = spawnSync("git", args, { cwd, encoding: "utf8" });
  if (result.status !== 0) throw new Error(result.stderr);
}

function treeFor(dir: string, entry: string) {
  const root = join(HERE, "fixtures", dir);
  const files = readdirSync(root)
    .filter((file) => file.endsWith(".ts"))
    .map((file) => join(root, file));
  const index = buildIndex(files);
  const decl = resolveEntry(index, entry);
  if (!decl) throw new Error(`entry not found: ${entry}`);
  return buildTree(index, decl, OPTS);
}

describe("render", () => {
  const tree = treeFor("after", "PiService.createAgentSession");
  const out = render(toRenderNode(tree), { theme: "none", diff: false });

  test("roots at the entry with its params", () => {
    expect(out.split("\n")[0]).toBe("PiService.createAgentSession(options)");
  });

  test("recurses into an extracted helper", () => {
    expect(out).toContain("├── PiService.getServices()");
    expect(out).toContain("│   ├── AuthStorage.create()");
    expect(out).toContain("│   └── createCodingTools()");
  });

  test("normalizes a resolved instance-method label to Class.method", () => {
    expect(out).toContain("DefaultResourceLoader.reload()");
    expect(out).not.toContain("loader.reload()");
  });

  test("renders `new` expressions", () => {
    expect(out).toContain("new ModelRegistry()");
  });

  test("groups if/else into branch nodes", () => {
    expect(out).toContain("├── if !options.sessionId");
    expect(out).toContain("├── else");
  });

  test("does not self-recurse a name shared by method and free function", () => {
    expect(out).not.toContain("↻ recursive");
    expect(out.trimEnd().endsWith("└── createAgentSession()")).toBe(true);
  });
});

describe("cli", () => {
  test("renders a fixture through the public command", () => {
    const result = runCli(
      "PiService.createAgentSession",
      "--root",
      join(HERE, "fixtures", "after"),
      "--theme",
      "none"
    );

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("PiService.createAgentSession(options)");
    expect(result.stderr).toBe("");
  });

  test("diffs a git revision against the working tree through the public command", () => {
    const repository = mkdtempSync(join(tmpdir(), "csd-test-"));
    try {
      for (const file of ["pi-service.ts", "tools.ts"]) {
        copyFileSync(join(HERE, "fixtures", "before", file), join(repository, file));
      }
      git(repository, "init", "--quiet");
      git(repository, "add", "pi-service.ts", "tools.ts");
      git(
        repository,
        "-c",
        "user.name=callstack-diff test",
        "-c",
        "user.email=csd@example.invalid",
        "commit",
        "--quiet",
        "-m",
        "before"
      );
      for (const file of ["pi-service.ts", "tools.ts"]) {
        copyFileSync(join(HERE, "fixtures", "after", file), join(repository, file));
      }

      const result = runCli(
        "diff",
        "PiService.createAgentSession",
        "--root",
        repository,
        "--from",
        "HEAD",
        "--theme",
        "none"
      );

      expect(result.exitCode).toBe(0);
      expect(result.stdout).toContain("- ├── AuthStorage.create()");
      expect(result.stdout).toContain("+ ├── PiService.getServices()");
      expect(result.stderr).toBe("");
    } finally {
      rmSync(repository, { recursive: true, force: true });
    }
  });
});

describe("diff", () => {
  const before = treeFor("before", "PiService.createAgentSession");
  const after = treeFor("after", "PiService.createAgentSession");
  const out = render(diffTrees(before, after), { theme: "none", diff: true });

  test("marks removed inline construction", () => {
    expect(out).toContain("- ├── AuthStorage.create()");
    expect(out).toContain("- ├── new ModelRegistry()");
  });

  test("marks the added helper subtree", () => {
    expect(out).toContain("+ ├── PiService.getServices()");
    expect(out).toContain("+ │   ├── SettingsManager.create()");
    expect(out).toContain("+ │   └── createCodingTools()");
  });

  test("keeps unchanged branches as context", () => {
    expect(out).toContain("  ├── if !options.sessionId");
    expect(out).toContain("  │   ├── SessionManager.list()");
  });
});

describe("no-branches mode", () => {
  test("inlines branch bodies without group nodes", () => {
    const root = join(HERE, "fixtures", "after");
    const files = readdirSync(root)
      .filter((file) => file.endsWith(".ts"))
      .map((file) => join(root, file));
    const index = buildIndex(files);
    const decl = resolveEntry(index, "PiService.createAgentSession")!;
    const tree = buildTree(index, decl, { ...OPTS, groupBranches: false });
    const out = render(toRenderNode(tree), { theme: "none", diff: false });
    expect(out).not.toContain("if !options.sessionId");
    expect(out).toContain("SessionManager.create()");
    expect(out).toContain("SessionManager.open()");
  });
});
