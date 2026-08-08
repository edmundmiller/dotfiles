// Build a static call-stack tree from an entry declaration by walking its
// body in source order, grouping control-flow branches, and recursing into
// resolved callees.
import type { FnDecl, Node, ProjectIndex } from "./project.ts";

export type NodeKind = "root" | "call" | "new" | "branch" | "note";

export interface CallNode {
  label: string;
  kind: NodeKind;
  children: CallNode[];
}

export interface BuildOptions {
  maxDepth: number;
  groupBranches: boolean;
  showArgs: boolean;
}

function src(decl: FnDecl, node: Node): string {
  return decl.source.slice(node.start, node.end);
}

// Collect the outermost call/new expressions within an expression, in source
// order. We do not descend into a call's own arguments or callee: those calls
// belong to the resolution of surrounding statements, not this call's siblings.
function outermostCalls(expr: Node): Node[] {
  const found: Node[] = [];
  const visit = (n: Node): void => {
    if (!n || typeof n !== "object") return;
    if (n.type === "CallExpression" || n.type === "NewExpression") {
      found.push(n);
      return; // stop: do not treat nested calls as siblings
    }
    for (const key of Object.keys(n)) {
      if (key === "type" || key === "start" || key === "end") continue;
      const value = (n as any)[key];
      if (Array.isArray(value)) value.forEach(visit);
      else if (value && typeof value === "object") visit(value);
    }
  };
  visit(expr);
  return found.sort((a, b) => a.start - b.start);
}

interface Ctx {
  index: ProjectIndex;
  decl: FnDecl; // declaration whose body we are walking (for source slicing)
  opts: BuildOptions;
  stack: FnDecl[]; // recursion guard
  depth: number;
}

function calleeText(decl: FnDecl, call: Node): string {
  const callee = call.callee;
  return decl.source.slice(callee.start, callee.end);
}

function argsText(decl: FnDecl, call: Node): string {
  if (!call.arguments?.length) return "";
  const first = call.arguments[0];
  const last = call.arguments[call.arguments.length - 1];
  return decl.source.slice(first.start, last.end);
}

// Find the class name a static member call targets, e.g. `Foo.bar()` -> "Foo".
function staticClassOf(call: Node): string | undefined {
  const callee = call.callee;
  if (callee?.type === "MemberExpression" && callee.object?.type === "Identifier")
    return callee.object.name;
  return undefined;
}

function methodName(call: Node): string | undefined {
  const callee = call.callee;
  if (callee?.type === "MemberExpression" && callee.property?.type === "Identifier")
    return callee.property.name;
  if (callee?.type === "Identifier") return callee.name;
  return undefined;
}

function resolveCall(index: ProjectIndex, call: Node): FnDecl | undefined {
  if (call.type === "NewExpression") {
    const name = call.callee?.type === "Identifier" ? call.callee.name : undefined;
    if (name) return index.byQualified.get(`${name}.constructor`);
    return undefined;
  }
  const cls = staticClassOf(call);
  const name = methodName(call);
  if (cls && name && index.byQualified.has(`${cls}.${name}`))
    return index.byQualified.get(`${cls}.${name}`);
  if (!name) return undefined;
  const candidates = index.byName.get(name) ?? [];
  // A bare `foo()` cannot dispatch to an instance/static method without a
  // receiver, so prefer free functions/arrows over class members.
  if (call.callee?.type === "Identifier")
    return candidates.find((d) => d.kind === "function" || d.kind === "arrow") ?? candidates[0];
  return candidates[0];
}

function callNode(ctx: Ctx, call: Node): CallNode {
  const isNew = call.type === "NewExpression";
  const args = ctx.opts.showArgs ? argsText(ctx.decl, call) : "";
  const target = resolveCall(ctx.index, call);

  // When a call resolves to a class member, normalize the label to
  // `Class.method` so `loader.reload()` reads as `DefaultResourceLoader.reload()`.
  const member =
    target && (target.kind === "method" || target.kind === "constructor") ? target : undefined;
  const base =
    member && member.className && !isNew
      ? `${member.className}.${member.name}`
      : calleeText(ctx.decl, call);
  const label = `${isNew ? "new " : ""}${base}(${args})`;
  const node: CallNode = { label, kind: isNew ? "new" : "call", children: [] };

  if (!target) return node; // external / unresolved: leaf
  if (ctx.stack.includes(target)) {
    node.children.push({ label: "↻ recursive", kind: "note", children: [] });
    return node;
  }
  if (ctx.depth + 1 > ctx.opts.maxDepth) return node;

  node.children = walkBody(
    {
      index: ctx.index,
      decl: target,
      opts: ctx.opts,
      stack: [...ctx.stack, target],
      depth: ctx.depth + 1,
    },
    target.body
  );
  return node;
}

function callsFromExpr(ctx: Ctx, expr: Node): CallNode[] {
  return outermostCalls(expr).map((c) => callNode(ctx, c));
}

function branchLabel(ctx: Ctx, node: Node): string {
  return ctx.decl.source.slice(node.start, node.end).replace(/\s+/g, " ");
}

function walkStatement(ctx: Ctx, stmt: Node): CallNode[] {
  if (!stmt) return [];
  switch (stmt.type) {
    case "ExpressionStatement":
      return callsFromExpr(ctx, stmt.expression);
    case "VariableDeclaration":
      return (stmt.declarations ?? []).flatMap((d: Node) =>
        d.init ? callsFromExpr(ctx, d.init) : []
      );
    case "ReturnStatement":
    case "ThrowStatement":
    case "AwaitExpression":
      return stmt.argument ? callsFromExpr(ctx, stmt.argument) : [];
    case "BlockStatement":
      return walkStatements(ctx, stmt.body);
    case "IfStatement":
      return walkIf(ctx, stmt);
    case "SwitchStatement":
      return walkSwitch(ctx, stmt);
    case "TryStatement": {
      const out = walkStatements(ctx, stmt.block?.body ?? []);
      if (stmt.handler?.body) out.push(...walkStatements(ctx, stmt.handler.body.body));
      if (stmt.finalizer) out.push(...walkStatements(ctx, stmt.finalizer.body));
      return out;
    }
    case "ForStatement":
    case "ForInStatement":
    case "ForOfStatement":
    case "WhileStatement":
    case "DoWhileStatement": {
      const body = stmt.body;
      const inner =
        body?.type === "BlockStatement" ? walkStatements(ctx, body.body) : walkStatement(ctx, body);
      return inner;
    }
    default:
      return [];
  }
}

function walkIf(ctx: Ctx, stmt: Node): CallNode[] {
  const cons =
    stmt.consequent?.type === "BlockStatement"
      ? walkStatements(ctx, stmt.consequent.body)
      : walkStatement(ctx, stmt.consequent);
  const altNode = stmt.alternate;
  const alt = altNode
    ? altNode.type === "IfStatement"
      ? walkIf(ctx, altNode) // else-if chain
      : altNode.type === "BlockStatement"
        ? walkStatements(ctx, altNode.body)
        : walkStatement(ctx, altNode)
    : [];

  if (!ctx.opts.groupBranches) return [...cons, ...alt];

  const out: CallNode[] = [];
  if (cons.length)
    out.push({
      label: `if ${branchLabel(ctx, stmt.test)}`,
      kind: "branch",
      children: cons,
    });
  if (altNode && altNode.type !== "IfStatement" && alt.length)
    out.push({ label: "else", kind: "branch", children: alt });
  else if (altNode && altNode.type === "IfStatement") out.push(...alt);
  return out;
}

function walkSwitch(ctx: Ctx, stmt: Node): CallNode[] {
  const out: CallNode[] = [];
  for (const c of stmt.cases ?? []) {
    const body = walkStatements(ctx, c.consequent ?? []);
    if (!body.length) continue;
    const label = c.test ? `case ${branchLabel(ctx, c.test)}` : "default";
    if (ctx.opts.groupBranches) out.push({ label, kind: "branch", children: body });
    else out.push(...body);
  }
  return out;
}

function walkStatements(ctx: Ctx, stmts: Node[]): CallNode[] {
  return (stmts ?? []).flatMap((s) => walkStatement(ctx, s));
}

function walkBody(ctx: Ctx, body: Node): CallNode[] {
  if (!body) return [];
  if (body.type === "BlockStatement") return walkStatements(ctx, body.body);
  // Concise arrow body: an expression that may contain calls.
  return callsFromExpr(ctx, body);
}

export function buildTree(index: ProjectIndex, entry: FnDecl, opts: BuildOptions): CallNode {
  const display = entry.qualified ?? entry.name;
  const rootLabel = `${display}(${entry.params.join(", ")})`;
  const ctx: Ctx = { index, decl: entry, opts, stack: [entry], depth: 0 };
  return {
    label: rootLabel,
    kind: "root",
    children: walkBody(ctx, entry.body),
  };
}
