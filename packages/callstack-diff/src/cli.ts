#!/usr/bin/env bun
// callstack-diff (csd): render or diff static call-stack trees for JS/TS.
import { Glob } from "bun";
import { isAbsolute, join, resolve } from "node:path";
import { buildIndex, resolveEntry } from "./project.ts";
import { buildTree, type BuildOptions } from "./tree.ts";
import { diffTrees } from "./diff.ts";
import { render, toRenderNode, type Theme } from "./render.ts";
import { materializeRef, repoRoot } from "./git.ts";

const DEFAULT_GLOB = "**/*.{ts,tsx,mts,cts,js,jsx,mjs,cjs}";
const IGNORE = ["**/node_modules/**", "**/dist/**", "**/.git/**", "**/build/**"];

interface Args {
  command: "render" | "diff";
  entry?: string;
  paths: string[];
  root: string;
  depth: number;
  groupBranches: boolean;
  showArgs: boolean;
  theme: Theme;
  from: string;
  to?: string; // undefined => working tree
}

function usage(): string {
  return `csd — static call-stack trees for JS/TS (powered by Oxc)

Usage:
  csd <entry> [paths...] [options]          render a call-stack tree
  csd diff <entry> [paths...] [options]     diff the tree between two revisions

Entry:
  name            bare function/arrow name
  Class.method    class member (static or instance)
  file.ts#name    disambiguate by file

Options:
  --root <dir>        analysis root (default: cwd)
  --depth <n>         max recursion depth (default: 6)
  --no-branches       do not group if/else/switch into branch nodes
  --args              include raw call arguments in labels
  --theme <t>         color theme: default | libretto | none (default: default)
  --from <ref>        diff: base git ref (default: HEAD)
  --to <ref>          diff: target git ref (default: working tree)
  -h, --help          show this help`;
}

function parseArgs(argv: string[]): Args {
  const args: Args = {
    command: "render",
    paths: [],
    root: process.cwd(),
    depth: 6,
    groupBranches: true,
    showArgs: false,
    theme: "default",
    from: "HEAD",
  };
  let rest = argv;
  if (rest[0] === "diff") {
    args.command = "diff";
    rest = rest.slice(1);
  }
  const positional: string[] = [];
  for (let i = 0; i < rest.length; i++) {
    const a = rest[i];
    switch (a) {
      case "-h":
      case "--help":
        console.log(usage());
        process.exit(0);
      case "--root":
        args.root = resolve(rest[++i]);
        break;
      case "--depth":
        args.depth = Number(rest[++i]);
        break;
      case "--no-branches":
        args.groupBranches = false;
        break;
      case "--args":
        args.showArgs = true;
        break;
      case "--theme":
        args.theme = rest[++i] as Theme;
        break;
      case "--from":
        args.from = rest[++i];
        break;
      case "--to":
        args.to = rest[++i];
        break;
      default:
        if (a.startsWith("--")) {
          process.stderr.write(`unknown option: ${a}\n`);
          process.exit(2);
        }
        positional.push(a);
    }
  }
  args.entry = positional.shift();
  args.paths = positional;
  return args;
}

function discover(root: string, paths: string[]): string[] {
  const patterns = paths.length ? paths : [DEFAULT_GLOB];
  const seen = new Set<string>();
  for (const pattern of patterns) {
    const isConcreteFile =
      !pattern.includes("*") && /\.(mts|cts|ts|tsx|mjs|cjs|js|jsx)$/.test(pattern);
    if (isConcreteFile) {
      seen.add(isAbsolute(pattern) ? pattern : join(root, pattern));
      continue;
    }
    const glob = new Glob(pattern);
    for (const rel of glob.scanSync({ cwd: root, onlyFiles: true, dot: false })) {
      if (IGNORE.some((ig) => new Glob(ig).match(rel))) continue;
      seen.add(join(root, rel));
    }
  }
  return [...seen];
}

function analyze(root: string, args: Args) {
  const files = discover(root, args.paths);
  if (!files.length) {
    process.stderr.write(`csd: no source files under ${root}\n`);
    process.exit(1);
  }
  const index = buildIndex(files);
  const entry = resolveEntry(index, args.entry!);
  if (!entry) {
    process.stderr.write(`csd: could not resolve entry "${args.entry}"\n`);
    process.exit(1);
  }
  const opts: BuildOptions = {
    maxDepth: args.depth,
    groupBranches: args.groupBranches,
    showArgs: args.showArgs,
  };
  return buildTree(index, entry, opts);
}

function main(): void {
  const args = parseArgs(process.argv.slice(2));
  if (!args.entry) {
    console.log(usage());
    process.exit(args.command === "render" ? 0 : 2);
  }

  if (args.command === "render") {
    const tree = analyze(args.root, args);
    console.log(render(toRenderNode(tree), { theme: args.theme, diff: false }));
    return;
  }

  // diff
  const root = repoRoot(args.root);
  const fromDir = materializeRef(args.from, root);
  const before = analyze(fromDir, args);
  const after = args.to ? analyze(materializeRef(args.to, root), args) : analyze(root, args);
  const merged = diffTrees(before, after);
  console.log(render(merged, { theme: args.theme, diff: true }));
}

main();
