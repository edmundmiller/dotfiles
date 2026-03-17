/** Snapshot builders and file-tree helpers for the QMD panel and plain-text fallback. */

import {
  get_active_document_paths,
  get_index_health,
  get_status,
  handelize_path,
  list_contexts,
  scan_filesystem_paths,
} from "../core/qmd-store.js";
import type { FreshnessResult, RepoBindingResult } from "../core/types.js";

// ── Search result type ───────────────────────────────────────

export interface QmdSearchResult {
  file: string;
  display_path: string;
  title: string;
  score: number;
  snippet: string;
  docid: string;
  source: "lex" | "hybrid";
}

export function normalize_lex_result(
  result: {
    filepath: string;
    displayPath: string;
    title: string;
    score: number;
    body?: string;
    docid: string;
  },
  _collection: string
): QmdSearchResult {
  return {
    file: result.filepath,
    display_path: strip_virtual_prefix(result.displayPath || result.filepath),
    title: result.title,
    score: result.score,
    snippet: clean_snippet(result.body ?? ""),
    docid: result.docid,
    source: "lex",
  };
}

export function normalize_vector_result(
  result: {
    filepath: string;
    displayPath: string;
    title: string;
    score: number;
    body?: string;
    docid: string;
  },
  _collection: string
): QmdSearchResult {
  return {
    file: result.filepath,
    display_path: strip_virtual_prefix(result.displayPath || result.filepath),
    title: result.title,
    score: result.score,
    snippet: clean_snippet(result.body ?? ""),
    docid: result.docid,
    source: "hybrid", // display as hybrid since it's vector-based
  };
}

export function normalize_hybrid_result(result: {
  file: string;
  displayPath: string;
  title: string;
  score: number;
  bestChunk: string;
  docid: string;
}): QmdSearchResult {
  return {
    file: result.file,
    display_path: strip_virtual_prefix(result.displayPath || result.file),
    title: result.title,
    score: result.score,
    snippet: clean_snippet(result.bestChunk ?? ""),
    docid: result.docid,
    source: "hybrid",
  };
}

function strip_virtual_prefix(path: string): string {
  // Strip qmd://collection/ prefix if present
  const match = path.match(/^qmd:\/\/[^/]+\/(.+)$/);
  if (match) return match[1];
  return path;
}

function clean_snippet(text: string): string {
  // Strip @@ diff headers
  let cleaned = text.replace(/@@\s*-?\d+(?:,\d+)?\s*(?:\+\d+(?:,\d+)?)?\s*@@/g, "");
  // Collapse multiple blank lines
  cleaned = cleaned.replace(/\n{3,}/g, "\n\n");
  cleaned = cleaned.trim();
  // Truncate to ~200 chars
  if (cleaned.length > 200) {
    cleaned = `…${cleaned.slice(0, 197)}…`;
  }
  return cleaned;
}

// ── Snapshot type ───────────────────────────────────────────

export type QmdSelectionScope = "bound" | "external" | "none";

export interface QmdCollectionSummary {
  key: string;
  repo_root: string | null;
  glob_pattern: string | null;
  doc_count: number;
  is_bound_collection: boolean;
}

export interface QmdPanelSnapshot {
  // Binding
  binding_status: "indexed" | "not_indexed" | "unavailable";
  repo_root: string | null;
  collection_key: string | null; // currently selected collection
  bound_collection_key: string | null;
  selected_collection_scope: QmdSelectionScope;
  supports_update_action: boolean;
  supports_file_toggling: boolean;
  read_only_reason: string | null;
  binding_source: "marker" | "store" | null;
  error_reason: string | null;

  // Collection catalog
  collections: QmdCollectionSummary[];

  // Freshness (bound collection only)
  freshness_status: "fresh" | "stale" | "unknown" | null;
  stale_paths: string[];
  stale_count: number;

  // Index stats (selected collection + global health)
  total_documents: number;
  needs_embedding: number;
  has_vector_index: boolean;
  glob_pattern: string | null;
  last_indexed_at: string | null;
  last_indexed_commit: string | null;

  // Contexts (selected collection)
  contexts: Array<{ path: string; annotation: string }>;

  // Selected file paths for detail view (filesystem for bound, QMD paths for external)
  indexed_paths: string[];
  filesystem_paths: string[];
  file_paths_source: "filesystem" | "qmd" | "none";
}

// ── Snapshot builder ────────────────────────────────────────

export async function build_qmd_panel_snapshot(
  _cwd: string,
  binding: RepoBindingResult,
  freshness: FreshnessResult | undefined,
  selected_collection_key?: string
): Promise<QmdPanelSnapshot> {
  if (binding.status === "unavailable") {
    return empty_snapshot("unavailable", binding.repo_root ?? null, binding.reason);
  }

  try {
    const [status, contexts, health] = await Promise.all([
      get_status(),
      list_contexts(),
      get_index_health(),
    ]);

    const bound_collection_key = binding.status === "indexed" ? binding.collection_key : null;
    const collections: QmdCollectionSummary[] = status.collections.map((collection) => ({
      key: collection.name,
      repo_root: collection.path,
      glob_pattern: collection.pattern,
      doc_count: collection.documentCount,
      is_bound_collection: collection.name === bound_collection_key,
    }));

    const resolved_selected_key = resolve_selected_collection_key(
      selected_collection_key,
      bound_collection_key,
      collections
    );
    const selected_collection =
      collections.find((collection) => collection.key === resolved_selected_key) ?? null;
    const selected_scope = resolve_selection_scope(resolved_selected_key, bound_collection_key);

    const qmd_paths = resolved_selected_key
      ? await get_active_document_paths(resolved_selected_key)
      : [];

    let indexed_paths: string[] = [];
    let filesystem_paths: string[] = [];
    let file_paths_source: QmdPanelSnapshot["file_paths_source"] = "none";

    if (selected_scope === "bound" && binding.status === "indexed") {
      const fs_paths = await scan_filesystem_paths(binding.repo_root);
      const qmd_indexed_set = new Set(qmd_paths);
      indexed_paths = fs_paths.filter((fs_path) => qmd_indexed_set.has(handelize_path(fs_path)));
      filesystem_paths = fs_paths;
      file_paths_source = "filesystem";
    } else if (selected_scope === "external" && resolved_selected_key) {
      indexed_paths = [...qmd_paths];
      filesystem_paths = [...qmd_paths];
      file_paths_source = "qmd";
    }

    return {
      binding_status: binding.status,
      repo_root: binding.repo_root,
      collection_key: resolved_selected_key,
      bound_collection_key,
      selected_collection_scope: selected_scope,
      supports_update_action: selected_scope === "bound",
      supports_file_toggling: selected_scope === "bound",
      read_only_reason:
        selected_scope === "external"
          ? "Selected collection is read-only outside the bound repository."
          : null,
      binding_source: binding.status === "indexed" ? binding.source : null,
      error_reason: null,

      collections,

      freshness_status: selected_scope === "bound" ? (freshness?.status ?? null) : null,
      stale_paths:
        selected_scope === "bound" && freshness?.status === "stale" ? freshness.changed_paths : [],
      stale_count:
        selected_scope === "bound" && freshness?.status === "stale" ? freshness.changed_count : 0,

      total_documents: selected_collection?.doc_count ?? qmd_paths.length,
      needs_embedding: health.needs_embedding,
      has_vector_index: status.hasVectorIndex,
      glob_pattern: selected_collection?.glob_pattern ?? null,
      last_indexed_at:
        selected_scope === "bound" ? (binding.marker?.last_indexed_at ?? null) : null,
      last_indexed_commit:
        selected_scope === "bound" ? (binding.marker?.last_indexed_commit ?? null) : null,

      contexts: contexts
        .filter((context) => context.collection === resolved_selected_key)
        .map((context) => ({ path: context.path, annotation: context.context })),

      indexed_paths,
      filesystem_paths,
      file_paths_source,
    };
  } catch {
    return empty_snapshot("unavailable", binding.repo_root, "Failed to read QMD store data.");
  }
}

// ── Helpers ─────────────────────────────────────────────────

function resolve_selected_collection_key(
  explicit_key: string | undefined,
  bound_key: string | null,
  collections: QmdCollectionSummary[]
): string | null {
  if (explicit_key && collections.some((collection) => collection.key === explicit_key)) {
    return explicit_key;
  }

  if (bound_key && collections.some((collection) => collection.key === bound_key)) {
    return bound_key;
  }

  return collections[0]?.key ?? null;
}

function resolve_selection_scope(
  selected_key: string | null,
  bound_key: string | null
): QmdSelectionScope {
  if (!selected_key) {
    return "none";
  }
  if (bound_key && selected_key === bound_key) {
    return "bound";
  }
  return "external";
}

function empty_snapshot(
  status: "not_indexed" | "unavailable",
  repo_root: string | null,
  error_reason: string | null
): QmdPanelSnapshot {
  return {
    binding_status: status,
    repo_root,
    collection_key: null,
    bound_collection_key: null,
    selected_collection_scope: "none",
    supports_update_action: false,
    supports_file_toggling: false,
    read_only_reason: null,
    binding_source: null,
    error_reason,

    collections: [],

    freshness_status: null,
    stale_paths: [],
    stale_count: 0,

    total_documents: 0,
    needs_embedding: 0,
    has_vector_index: false,
    glob_pattern: null,
    last_indexed_at: null,
    last_indexed_commit: null,

    contexts: [],
    indexed_paths: [],
    filesystem_paths: [],
    file_paths_source: "none",
  };
}

export function format_relative_time(iso_string: string): string {
  const now = Date.now();
  const then = new Date(iso_string).getTime();
  if (Number.isNaN(then)) return "unknown";

  const diff_ms = now - then;
  if (diff_ms < 0) return "just now";

  const seconds = Math.floor(diff_ms / 1000);
  if (seconds < 60) return "just now";

  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;

  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}d ago`;

  const months = Math.floor(days / 30);
  return `${months}mo ago`;
}

export function group_paths_by_directory(paths: string[]): Map<string, string[]> {
  const groups = new Map<string, string[]>();

  for (const file_path of paths) {
    const slash_idx = file_path.indexOf("/");
    const dir = slash_idx === -1 ? "." : file_path.slice(0, slash_idx);
    const existing = groups.get(dir);
    if (existing) {
      existing.push(file_path);
    } else {
      groups.set(dir, [file_path]);
    }
  }

  // Sort files within each group
  for (const files of groups.values()) {
    files.sort();
  }

  return groups;
}

// ── File tree ───────────────────────────────────────────────

export type DirIndexStatus = "all" | "some" | "none";

export interface FileTreeNode {
  name: string;
  path: string;
  is_dir: boolean;
  children: FileTreeNode[];
  file_count: number;
  /** For files: whether the file is in the QMD index */
  indexed: boolean;
  /** For dirs: aggregate index status of descendant files */
  dir_index_status: DirIndexStatus;
}

/**
 * Build a hierarchical tree from flat file paths.
 * Directories that contain only a single child directory are collapsed
 * into one node (e.g. `docs/exec-plans/active` instead of three levels).
 *
 * @param paths All file paths to include in the tree
 * @param indexed_set Set of paths that are currently indexed in QMD
 */
export function build_file_tree(paths: string[], indexed_set?: Set<string>): FileTreeNode[] {
  const idx = indexed_set ?? new Set<string>();
  const root: FileTreeNode = {
    name: "",
    path: "",
    is_dir: true,
    children: [],
    file_count: 0,
    indexed: false,
    dir_index_status: "none",
  };

  for (const file_path of paths) {
    const segments = file_path.split("/");
    let current = root;

    for (let i = 0; i < segments.length; i++) {
      const seg = segments[i];
      const is_last = i === segments.length - 1;

      if (is_last) {
        // File node
        current.children.push({
          name: seg,
          path: file_path,
          is_dir: false,
          children: [],
          file_count: 0,
          indexed: idx.has(file_path),
          dir_index_status: "none",
        });
      } else {
        // Directory node — find or create
        const partial_path = segments.slice(0, i + 1).join("/");
        let child = current.children.find((c) => c.is_dir && c.path === partial_path);
        if (!child) {
          child = {
            name: seg,
            path: partial_path,
            is_dir: true,
            children: [],
            file_count: 0,
            indexed: false,
            dir_index_status: "none",
          };
          current.children.push(child);
        }
        current = child;
      }
    }
  }

  // Count files recursively
  count_files(root);

  // Compute dir index status
  compute_dir_index_status(root);

  // Sort: dirs first (alphabetical), then files (alphabetical)
  sort_tree(root);

  // Collapse single-child directory chains
  collapse_single_child_dirs(root);

  return root.children;
}

function count_files(node: FileTreeNode): number {
  if (!node.is_dir) {
    node.file_count = 0;
    return 1;
  }
  let total = 0;
  for (const child of node.children) {
    total += count_files(child);
  }
  node.file_count = total;
  return total;
}

/** Compute aggregate index status for directories based on descendant files. */
function compute_dir_index_status(node: FileTreeNode): { indexed: number; total: number } {
  if (!node.is_dir) {
    return { indexed: node.indexed ? 1 : 0, total: 1 };
  }

  let indexed_count = 0;
  let total_count = 0;
  for (const child of node.children) {
    const r = compute_dir_index_status(child);
    indexed_count += r.indexed;
    total_count += r.total;
  }

  if (total_count === 0) {
    node.dir_index_status = "none";
  } else if (indexed_count === total_count) {
    node.dir_index_status = "all";
  } else if (indexed_count > 0) {
    node.dir_index_status = "some";
  } else {
    node.dir_index_status = "none";
  }

  return { indexed: indexed_count, total: total_count };
}

function sort_tree(node: FileTreeNode): void {
  if (!node.is_dir) return;
  node.children.sort((a, b) => {
    if (a.is_dir !== b.is_dir) return a.is_dir ? -1 : 1;
    return a.name.localeCompare(b.name);
  });
  for (const child of node.children) {
    sort_tree(child);
  }
}

function collapse_single_child_dirs(node: FileTreeNode): void {
  for (const child of node.children) {
    if (child.is_dir) {
      // Collapse chain: if a dir has exactly one child and it's also a dir, merge them
      while (child.children.length === 1 && child.children[0].is_dir) {
        const grandchild = child.children[0];
        child.name = `${child.name}/${grandchild.name}`;
        child.path = grandchild.path;
        child.children = grandchild.children;
        child.file_count = grandchild.file_count;
        child.dir_index_status = grandchild.dir_index_status;
      }
      collapse_single_child_dirs(child);
    }
  }
}

/**
 * Collect all descendant file paths from a tree node.
 */
export function collect_file_paths(node: FileTreeNode): string[] {
  const paths: string[] = [];
  function walk(n: FileTreeNode): void {
    if (!n.is_dir) {
      paths.push(n.path);
    } else {
      for (const child of n.children) {
        walk(child);
      }
    }
  }
  walk(node);
  return paths;
}

/**
 * Flatten the tree into a list of visible nodes, respecting the collapsed set.
 * Returns { node, depth, is_last_sibling } tuples for rendering tree lines.
 */
export interface FlatTreeEntry {
  node: FileTreeNode;
  depth: number;
  is_last: boolean;
  parent_is_last: boolean[];
}

export function flatten_tree(roots: FileTreeNode[], collapsed: Set<string>): FlatTreeEntry[] {
  const result: FlatTreeEntry[] = [];

  function walk(nodes: FileTreeNode[], depth: number, parent_is_last: boolean[]): void {
    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i];
      const is_last = i === nodes.length - 1;
      result.push({ node, depth, is_last, parent_is_last: [...parent_is_last] });

      if (node.is_dir && !collapsed.has(node.path)) {
        walk(node.children, depth + 1, [...parent_is_last, is_last]);
      }
    }
  }

  walk(roots, 0, []);
  return result;
}

/**
 * Wrap a plain string into multiple lines, each at most `max_width` characters.
 * Breaks at word boundaries when possible.
 */
export function wrap_text(text: string, max_width: number, indent = ""): string[] {
  if (text.length <= max_width) return [`${indent}${text}`];

  const lines: string[] = [];
  const indent_len = indent.length;
  const effective_width = max_width - indent_len;
  let remaining = text;

  while (remaining.length > 0) {
    if (remaining.length <= effective_width) {
      lines.push(`${indent}${remaining}`);
      break;
    }

    // Find last space within width
    let break_at = remaining.lastIndexOf(" ", effective_width);
    if (break_at <= 0) {
      // No good break point — hard break
      break_at = effective_width;
    }

    lines.push(`${indent}${remaining.slice(0, break_at)}`);
    remaining = remaining.slice(break_at).trimStart();
  }

  return lines;
}
