// Build a static call-stack tree from an entry declaration by walking its
// body in source order, grouping control-flow branches, and recursing into
// resolved callees.
import { isNode, nodeAt, nodesAt, type FnDecl, type Node, type ProjectIndex } from "./project.ts";

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
      const value = n[key];
      if (Array.isArray(value)) value.filter(isNode).forEach(visit);
      else if (isNode(value)) visit(value);
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
  const callee = nodeAt(call, "callee");
  if (!callee) return "";
  return decl.source.slice(callee.start, callee.end);
}

function argsText(decl: FnDecl, call: Node): string {
  const args = nodesAt(call, "arguments");
  if (args.length === 0) return "";
  const first = args[0];
  const last = args[args.length - 1];
  return decl.source.slice(first.start, last.end);
}

// Find the class name a static member call targets, e.g. `Foo.bar()` -> "Foo".
function staticClassOf(call: Node): string | undefined {
  const callee = nodeAt(call, "callee");
  const object = callee ? nodeAt(callee, "object") : undefined;
  if (callee?.type === "MemberExpression" && object?.type === "Identifier")
    return typeof object.name === "string" ? object.name : undefined;
  return undefined;
}

function methodName(call: Node): string | undefined {
  const callee = nodeAt(call, "callee");
  const property = callee ? nodeAt(callee, "property") : undefined;
  if (callee?.type === "MemberExpression" && property?.type === "Identifier")
    return typeof property.name === "string" ? property.name : undefined;
  if (callee?.type === "Identifier")
    return typeof callee.name === "string" ? callee.name : undefined;
  return undefined;
}

function resolveCall(index: ProjectIndex, call: Node): FnDecl | undefined {
  const callee = nodeAt(call, "callee");
  if (call.type === "NewExpression") {
    const name =
      callee?.type === "Identifier" && typeof callee.name === "string" ? callee.name : undefined;
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
  if (callee?.type === "Identifier")
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
  switch (stmt.type) {
    case "ExpressionStatement": {
      const expression = nodeAt(stmt, "expression");
      return expression ? callsFromExpr(ctx, expression) : [];
    }
    case "VariableDeclaration":
      return nodesAt(stmt, "declarations").flatMap((declaration) => {
        const init = nodeAt(declaration, "init");
        return init ? callsFromExpr(ctx, init) : [];
      });
    case "ReturnStatement":
    case "ThrowStatement":
    case "AwaitExpression": {
      const argument = nodeAt(stmt, "argument");
      return argument ? callsFromExpr(ctx, argument) : [];
    }
    case "BlockStatement":
      return walkStatements(ctx, nodesAt(stmt, "body"));
    case "IfStatement":
      return walkIf(ctx, stmt);
    case "SwitchStatement":
      return walkSwitch(ctx, stmt);
    case "TryStatement": {
      const block = nodeAt(stmt, "block");
      const out = walkStatements(ctx, block ? nodesAt(block, "body") : []);
      const handler = nodeAt(stmt, "handler");
      const handlerBody = handler ? nodeAt(handler, "body") : undefined;
      if (handlerBody) out.push(...walkStatements(ctx, nodesAt(handlerBody, "body")));
      const finalizer = nodeAt(stmt, "finalizer");
      if (finalizer) out.push(...walkStatements(ctx, nodesAt(finalizer, "body")));
      return out;
    }
    case "ForStatement":
    case "ForInStatement":
    case "ForOfStatement":
    case "WhileStatement":
    case "DoWhileStatement": {
      const body = nodeAt(stmt, "body");
      if (!body) return [];
      return body.type === "BlockStatement"
        ? walkStatements(ctx, nodesAt(body, "body"))
        : walkStatement(ctx, body);
    }
    default:
      return [];
  }
}

function walkIf(ctx: Ctx, stmt: Node): CallNode[] {
  const consequent = nodeAt(stmt, "consequent");
  const cons =
    consequent?.type === "BlockStatement"
      ? walkStatements(ctx, nodesAt(consequent, "body"))
      : consequent
        ? walkStatement(ctx, consequent)
        : [];
  const altNode = nodeAt(stmt, "alternate");
  const alt = altNode
    ? altNode.type === "IfStatement"
      ? walkIf(ctx, altNode) // else-if chain
      : altNode.type === "BlockStatement"
        ? walkStatements(ctx, nodesAt(altNode, "body"))
        : walkStatement(ctx, altNode)
    : [];

  if (!ctx.opts.groupBranches) return [...cons, ...alt];

  const out: CallNode[] = [];
  const test = nodeAt(stmt, "test");
  if (cons.length && test)
    out.push({
      label: `if ${branchLabel(ctx, test)}`,
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
  for (const c of nodesAt(stmt, "cases")) {
    const body = walkStatements(ctx, nodesAt(c, "consequent"));
    if (!body.length) continue;
    const test = nodeAt(c, "test");
    const label = test ? `case ${branchLabel(ctx, test)}` : "default";
    if (ctx.opts.groupBranches) out.push({ label, kind: "branch", children: body });
    else out.push(...body);
  }
  return out;
}

function walkStatements(ctx: Ctx, stmts: Node[]): CallNode[] {
  return (stmts ?? []).flatMap((s) => walkStatement(ctx, s));
}

function walkBody(ctx: Ctx, body: Node): CallNode[] {
  if (body.type === "BlockStatement") return walkStatements(ctx, nodesAt(body, "body"));
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
