// Render a call tree (optionally a diff-annotated one) as an ASCII tree with
// box-drawing connectors, matching the classic call-stack-diff layout.
import type { CallNode } from "./tree.ts";

export type Mark = "+" | "-" | " ";

export interface RenderNode {
  label: string;
  children: RenderNode[];
  mark?: Mark;
}

export type Theme = "default" | "libretto" | "none";

interface Palette {
  added: string;
  removed: string;
  context: string;
}

const RESET = "\u001b[0m";

const palettes: Record<Exclude<Theme, "none">, Palette> = {
  // git-style: green add, red remove, uncolored context
  default: { added: "\u001b[32m", removed: "\u001b[31m", context: "" },
  // screenshot-style: purple for changes, blue for context
  libretto: { added: "\u001b[35m", removed: "\u001b[35m", context: "\u001b[34m" },
};

export interface RenderOptions {
  theme: Theme;
  diff: boolean;
}

function colorize(text: string, mark: Mark, theme: Theme): string {
  if (theme === "none") return text;
  const pal = palettes[theme];
  const code = mark === "+" ? pal.added : mark === "-" ? pal.removed : pal.context;
  return code ? `${code}${text}${RESET}` : text;
}

export function render(root: RenderNode, opts: RenderOptions): string {
  const lines: string[] = [];

  const gutter = (mark: Mark): string => (opts.diff ? `${mark} ` : "");

  const emit = (text: string, mark: Mark): void => {
    lines.push(`${gutter(mark)}${colorize(text, mark, opts.theme)}`);
  };

  emit(root.label, root.mark ?? " ");

  const walk = (nodes: RenderNode[], prefix: string): void => {
    nodes.forEach((node, i) => {
      const last = i === nodes.length - 1;
      const connector = last ? "└── " : "├── ";
      emit(`${prefix}${connector}${node.label}`, node.mark ?? " ");
      const childPrefix = prefix + (last ? "    " : "│   ");
      if (node.children.length) walk(node.children, childPrefix);
    });
  };

  walk(root.children, "");
  return lines.join("\n");
}

export function toRenderNode(node: CallNode): RenderNode {
  return { label: node.label, children: node.children.map(toRenderNode) };
}
