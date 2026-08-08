// Parse a set of JS/TS files with Oxc and index their function-like
// declarations so call sites can be resolved to bodies by name.
import { parseSync } from "oxc-parser";
import { readFileSync } from "node:fs";
import { extname } from "node:path";

// Oxc emits an ESTree-shaped AST; we keep node types loose on purpose.
export type Node = any;

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
  return (params ?? []).map((p) => {
    const t = p?.type === "TSParameterProperty" ? p.parameter : p;
    if (t?.type === "Identifier") return t.name;
    if (t?.type === "RestElement" && t.argument?.type === "Identifier")
      return `...${t.argument.name}`;
    if (t?.type === "AssignmentPattern" && t.left?.type === "Identifier") return t.left.name;
    if (t?.type === "ObjectPattern") return "{…}";
    if (t?.type === "ArrayPattern") return "[…]";
    return "_";
  });
}

// Depth-first walk over every child node that carries a `.type`.
function walk(node: Node, visit: (n: Node) => void): void {
  if (!node || typeof node !== "object") return;
  if (typeof node.type === "string") visit(node);
  for (const key of Object.keys(node)) {
    if (key === "type" || key === "start" || key === "end") continue;
    const value = (node as any)[key];
    if (Array.isArray(value)) {
      for (const child of value) walk(child, visit);
    } else if (value && typeof value === "object") {
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
        if (n.id?.name)
          addFn(index, {
            name: n.id.name,
            kind: "function",
            file,
            params: paramNames(n.params),
            body: n.body,
            source,
          });
        break;
      }
      case "VariableDeclarator": {
        const init = n.init;
        if (
          n.id?.type === "Identifier" &&
          init &&
          (init.type === "ArrowFunctionExpression" || init.type === "FunctionExpression")
        )
          addFn(index, {
            name: n.id.name,
            kind: "arrow",
            file,
            params: paramNames(init.params),
            body: init.body,
            source,
          });
        break;
      }
      case "ClassDeclaration":
      case "ClassExpression": {
        const className = n.id?.name;
        if (className) index.classNames.add(className);
        for (const member of n.body?.body ?? []) {
          if (member.type !== "MethodDefinition" && member.type !== "PropertyDefinition") continue;
          const fn =
            member.type === "MethodDefinition"
              ? member.value
              : member.value?.type === "ArrowFunctionExpression" ||
                  member.value?.type === "FunctionExpression"
                ? member.value
                : null;
          if (!fn?.body) continue;
          const name =
            member.key?.name ?? (member.key?.type === "Identifier" ? member.key.name : undefined);
          if (!name) continue;
          const kind: FnKind = member.kind === "constructor" ? "constructor" : "method";
          addFn(index, {
            name,
            qualified: className ? `${className}.${name}` : undefined,
            kind,
            className,
            isStatic: !!member.static,
            file,
            params: paramNames(fn.params),
            body: fn.body,
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
  if (!res.program) return null;
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
  const bare = entry.includes(".") ? entry.split(".").pop()! : entry;
  return index.byName.get(bare)?.[0];
}
