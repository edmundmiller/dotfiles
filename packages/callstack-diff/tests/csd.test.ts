import { describe, expect, test } from "bun:test";
import { Glob } from "bun";
import { join } from "node:path";
import { buildIndex, resolveEntry } from "../src/project.ts";
import { buildTree, type BuildOptions } from "../src/tree.ts";
import { diffTrees } from "../src/diff.ts";
import { render, toRenderNode } from "../src/render.ts";

const OPTS: BuildOptions = { maxDepth: 6, groupBranches: true, showArgs: false };
const HERE = new URL(".", import.meta.url).pathname;

function treeFor(dir: string, entry: string) {
  const root = join(HERE, "fixtures", dir);
  const files = [...new Glob("**/*.ts").scanSync({ cwd: root })].map((r) => join(root, r));
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
    const files = [...new Glob("**/*.ts").scanSync({ cwd: root })].map((r) => join(root, r));
    const index = buildIndex(files);
    const decl = resolveEntry(index, "PiService.createAgentSession")!;
    const tree = buildTree(index, decl, { ...OPTS, groupBranches: false });
    const out = render(toRenderNode(tree), { theme: "none", diff: false });
    expect(out).not.toContain("if !options.sessionId");
    expect(out).toContain("SessionManager.create()");
    expect(out).toContain("SessionManager.open()");
  });
});
