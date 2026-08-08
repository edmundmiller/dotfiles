// Parse a set of JS/TS files with Oxc and index their function-like
// declarations so call sites can be resolved to bodies by name.
import { parseSync } from "oxc-parser";
import { readFileSync } from "node:fs";
import { extname } from "node:path";

// Oxc emits an ESTree-shaped AST. Validate its dynamic values once at this
// boundary, then keep the analyzer free of broad type assertions.
export interface Node extends Record<string, unknown> {
  readonly type: string;
  readonly start: number;
  readonly end: number;
}

export function isNode(value: unknown): value is Node {
  return (
    typeof value === "object" &&
    value !== null &&
    typeof Reflect.get(value, "type") === "string" &&
    typeof Reflect.get(value, "start") === "number" &&
    typeof Reflect.get(value, "end") === "number"
  );
}

export function nodeAt(node: Node, key: string): Node | undefined {
  const value = node[key];
  return isNode(value) ? value : undefined;
}

export function nodesAt(node: Node, key: string): Node[] {
  const value = node[key];
  return Array.isArray(value) ? value.filter(isNode) : [];
}

function stringAt(node: Node | undefined, key: string): string | undefined {
  const value = node?.[key];
  return typeof value === "string" ? value : undefined;
}

export type FnKind = "function" | "method" | "arrow" | "constructor";

export interface FnDecl {
  name: string; // bare name, e.g. "getServices"
  qualified?: string; // "PiService.getServices" for class members
  kind: FnKind;
  className?: string;
  isStatic?: boolean;
  file: string;
  params: string[];
  body: Node; // BlockStatement, or an expression for concise arrows
  source: string; // full source text of the owning file
}

export interface ProjectIndex {
  byName: Map<string, FnDecl[]>;
  byQualified: Map<string, FnDecl>;
  classNames: Set<string>;
}

const langByExt: Record<string, "js" | "jsx" | "ts" | "tsx"> = {
  ".js": "js",
  ".cjs": "js",
  ".mjs": "js",
  ".jsx": "jsx",
  ".ts": "ts",
  ".cts": "ts",
  ".mts": "ts",
  ".tsx": "tsx",
};

function langFor(file: string): "js" | "jsx" | "ts" | "tsx" {
  return langByExt[extname(file)] ?? "ts";
}

function paramNames(params: Node[]): string[] {
  return params.map((p) => {
    const t = p.type === "TSParameterProperty" ? nodeAt(p, "parameter") : p;
    if (!t) return "_";
    if (t.type === "Identifier") return stringAt(t, "name") ?? "_";
    const argument = nodeAt(t, "argument");
    if (t.type === "RestElement" && argument?.type === "Identifier")
      return `...${stringAt(argument, "name") ?? "_"}`;
    const left = nodeAt(t, "left");
    if (t.type === "AssignmentPattern" && left?.type === "Identifier")
      return stringAt(left, "name") ?? "_";
    if (t.type === "ObjectPattern") return "{…}";
    if (t.type === "ArrayPattern") return "[…]";
    return "_";
  });
}

// Depth-first walk over every child node that carries a `.type`.
function walk(node: Node, visit: (n: Node) => void): void {
  visit(node);
  for (const key of Object.keys(node)) {
    if (key === "type" || key === "start" || key === "end") continue;
    const value = node[key];
    if (Array.isArray(value)) {
      for (const child of value) if (isNode(child)) walk(child, visit);
    } else if (isNode(value)) {
      walk(value, visit);
    }
  }
}

function addFn(index: ProjectIndex, decl: FnDecl): void {
  const list = index.byName.get(decl.name) ?? [];
  list.push(decl);
  index.byName.set(decl.name, list);
  if (decl.qualified && !index.byQualified.has(decl.qualified))
    index.byQualified.set(decl.qualified, decl);
}

function indexProgram(index: ProjectIndex, program: Node, file: string, source: string): void {
  walk(program, (n) => {
    switch (n.type) {
      case "FunctionDeclaration": {
        const id = nodeAt(n, "id");
        const name = stringAt(id, "name");
        const body = nodeAt(n, "body");
        if (name && body)
          addFn(index, {
            name,
            kind: "function",
            file,
            params: paramNames(nodesAt(n, "params")),
            body,
            source,
          });
        break;
      }
      case "VariableDeclarator": {
        const id = nodeAt(n, "id");
        const init = nodeAt(n, "init");
        const name = stringAt(id, "name");
        const body = init ? nodeAt(init, "body") : undefined;
        if (
          id?.type === "Identifier" &&
          name &&
          init &&
          body &&
          (init.type === "ArrowFunctionExpression" || init.type === "FunctionExpression")
        )
          addFn(index, {
            name,
            kind: "arrow",
            file,
            params: paramNames(nodesAt(init, "params")),
            body,
            source,
          });
        break;
      }
      case "ClassDeclaration":
      case "ClassExpression": {
        const className = stringAt(nodeAt(n, "id"), "name");
        if (className) index.classNames.add(className);
        const classBody = nodeAt(n, "body");
        for (const member of classBody ? nodesAt(classBody, "body") : []) {
          if (member.type !== "MethodDefinition" && member.type !== "PropertyDefinition") continue;
          const value = nodeAt(member, "value");
          const fn =
            member.type === "MethodDefinition"
              ? value
              : value?.type === "ArrowFunctionExpression" || value?.type === "FunctionExpression"
                ? value
                : null;
          const body = fn ? nodeAt(fn, "body") : undefined;
          if (!fn || !body) continue;
          const key = nodeAt(member, "key");
          const name = stringAt(key, "name");
          if (!name) continue;
          const kind: FnKind =
            stringAt(member, "kind") === "constructor" ? "constructor" : "method";
          addFn(index, {
            name,
            qualified: className ? `${className}.${name}` : undefined,
            kind,
            className,
            isStatic: member.static === true,
            file,
            params: paramNames(nodesAt(fn, "params")),
            body,
            source,
          });
        }
        break;
      }
    }
  });
}

export function parseFile(file: string): { program: Node; source: string } | null {
  const source = readFileSync(file, "utf8");
  const res = parseSync(file, source, {
    sourceType: "module",
    lang: langFor(file),
  });
  if (res.errors?.length) {
    // Tolerate partial parses; surface once on stderr.
    process.stderr.write(
      `callstack-diff: ${res.errors.length} parse issue(s) in ${file}; continuing\n`
    );
  }
  if (!isNode(res.program)) return null;
  return { program: res.program, source };
}

export function buildIndex(files: string[]): ProjectIndex {
  const index: ProjectIndex = {
    byName: new Map(),
    byQualified: new Map(),
    classNames: new Set(),
  };
  for (const file of files) {
    let parsed: { program: Node; source: string } | null = null;
    try {
      parsed = parseFile(file);
    } catch (err) {
      process.stderr.write(`callstack-diff: failed to read ${file}: ${err}\n`);
    }
    if (parsed) indexProgram(index, parsed.program, file, parsed.source);
  }
  return index;
}

// Resolve an entry spec to a declaration.
//   "Class.method"  -> qualified lookup, else bare "method"
//   "file#name"     -> restrict to a file, then bare name
//   "name"          -> bare lookup
export function resolveEntry(index: ProjectIndex, entry: string): FnDecl | undefined {
  if (entry.includes("#")) {
    const [filePart, name] = entry.split("#");
    const list = index.byName.get(name) ?? [];
    return list.find((d) => d.file.endsWith(filePart)) ?? list[0];
  }
  if (index.byQualified.has(entry)) return index.byQualified.get(entry);
  const bare = entry.includes(".") ? (entry.split(".").pop() ?? entry) : entry;
  return index.byName.get(bare)?.[0];
}
