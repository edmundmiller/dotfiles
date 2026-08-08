// Diff two call trees into a single mark-annotated render tree. Children are
// aligned by label using an LCS so unchanged siblings stay put while added and
// removed nodes are marked "+"/"-".
import type { CallNode } from "./tree.ts";
import type { Mark, RenderNode } from "./render.ts";

function markAll(node: CallNode, mark: Mark): RenderNode {
  return {
    label: node.label,
    mark,
    children: node.children.map((c) => markAll(c, mark)),
  };
}

// Longest common subsequence over child labels; returns the aligned steps.
type Step =
  | { kind: "same"; a: CallNode; b: CallNode }
  | { kind: "add"; b: CallNode }
  | { kind: "del"; a: CallNode };

function align(a: CallNode[], b: CallNode[]): Step[] {
  const n = a.length;
  const m = b.length;
  const dp: number[][] = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(0));
  for (let i = n - 1; i >= 0; i--)
    for (let j = m - 1; j >= 0; j--)
      dp[i][j] =
        a[i].label === b[j].label ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);

  const steps: Step[] = [];
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (a[i].label === b[j].label) {
      steps.push({ kind: "same", a: a[i], b: b[j] });
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      steps.push({ kind: "del", a: a[i] });
      i++;
    } else {
      steps.push({ kind: "add", b: b[j] });
      j++;
    }
  }
  while (i < n) steps.push({ kind: "del", a: a[i++] });
  while (j < m) steps.push({ kind: "add", b: b[j++] });
  return steps;
}

function diffChildren(a: CallNode[], b: CallNode[]): RenderNode[] {
  const out: RenderNode[] = [];
  for (const step of align(a, b)) {
    if (step.kind === "del") out.push(markAll(step.a, "-"));
    else if (step.kind === "add") out.push(markAll(step.b, "+"));
    else
      out.push({
        label: step.b.label,
        mark: " ",
        children: diffChildren(step.a.children, step.b.children),
      });
  }
  return out;
}

// Diff two trees that share a root entry. The root is treated as context.
export function diffTrees(before: CallNode, after: CallNode): RenderNode {
  return {
    label: after.label,
    mark: " ",
    children: diffChildren(before.children, after.children),
  };
}
