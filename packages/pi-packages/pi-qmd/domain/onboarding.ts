/** Deterministic QMD onboarding pipeline: scan, draft, normalize, and execute init. */

import { readdir, stat } from "node:fs/promises";
import path from "node:path";
import { InvalidInitProposalError } from "../core/errors.js";
import {
  add_collection,
  embed_pending,
  has_dot_segment,
  index_files,
  scan_filesystem_paths,
  set_contexts,
  update_collection,
} from "../core/qmd-store.js";
import {
  type ConfirmedInitProposal,
  type DraftInitProposal,
  draft_init_proposal_schema,
  type InitResult,
  type NormalizedInitProposal,
  normalized_init_proposal_schema,
  qmd_init_params_schema,
  type QmdEmbedResult,
  type QmdRepoMarker,
  type RepoScan,
} from "../core/types.js";
import { get_repo_head_commit } from "./freshness.js";
import {
  collection_key_from_repo_root,
  read_repo_marker,
  write_repo_marker,
} from "./repo-binding.js";

const DEFAULT_GLOB_PATTERN = "**/*.md";
const SCAN_LIMIT = 6000;
const SAMPLE_LIMIT = 40;
const SKIPPED_DIRECTORIES = new Set([
  ".git",
  "node_modules",
  "dist",
  "build",
  "coverage",
  ".next",
  ".turbo",
  ".cache",
]);

const CONTEXT_HEURISTICS: Record<string, string> = {
  ".pi": "Agent runtime memory, repo-local context, and workflow state.",
  docs: "Project documentation, architecture notes, design decisions, and reference material.",
  extensions: "Pi extension implementations and extension-specific documentation.",
  skills: "Agent skills, operator guidance, and reusable task instructions.",
  src: "Source code documentation, architecture notes, and implementation-adjacent markdown.",
  packages: "Package-level documentation for multi-package repositories.",
  apps: "Application-specific docs and per-app markdown content.",
  scripts: "Operational scripts plus any adjacent markdown documentation.",
  tests: "Testing notes, fixtures, and validation-oriented documentation.",
};

function to_posix_relative_path(repo_root: string, absolute_path: string): string {
  const relative_path = path.relative(repo_root, absolute_path);
  return relative_path === "" ? "" : relative_path.split(path.sep).join("/");
}

function is_markdown_file(file_name: string): boolean {
  return /\.mdx?$/iu.test(file_name);
}

function compare_paths(left: { path: string }, right: { path: string }): number {
  if (left.path.length !== right.path.length) {
    return left.path.length - right.path.length;
  }
  return left.path.localeCompare(right.path);
}

function normalize_annotation(value: string): string {
  return value.replace(/\s+/gu, " ").trim();
}

function normalize_context_path(input: string, repo_root: string): string {
  const trimmed = input.trim();
  if (trimmed === "" || trimmed === "." || trimmed === "/") {
    return "";
  }

  const normalized = path.posix.normalize(trimmed.split("\\").join("/")).replace(/^\.\//u, "");
  if (normalized === ".." || normalized.startsWith("../") || path.isAbsolute(normalized)) {
    throw new InvalidInitProposalError(
      `Context path '${input}' escapes the repository root ${repo_root}. Use repo-relative paths only.`
    );
  }
  return normalized.replace(/\/$/u, "");
}

export async function scan_repo(root: string): Promise<RepoScan> {
  const directory_stats = new Map<string, { file_count: number; markdown_file_count: number }>();
  const sample_paths: string[] = [];
  const key_files: string[] = [];
  const seen_key_files = new Set<string>();
  let markdown_file_count = 0;
  let visited_entries = 0;
  let truncated = false;

  const key_file_candidates = new Set([
    "README.md",
    "AGENTS.md",
    "package.json",
    "docs/ARCHITECTURE.md",
    "docs/QUALITY.md",
    "docs/CONTRIBUTING-DOCS.md",
  ]);

  async function walk(directory: string): Promise<void> {
    if (truncated) {
      return;
    }

    const entries = await readdir(directory, { withFileTypes: true });
    for (const entry of entries) {
      if (truncated) {
        return;
      }

      const absolute_path = path.join(directory, entry.name);
      const relative_path = to_posix_relative_path(root, absolute_path);
      const top_level = relative_path.split("/")[0] || ".";

      visited_entries += 1;
      if (visited_entries >= SCAN_LIMIT) {
        truncated = true;
        return;
      }

      if (entry.isDirectory()) {
        if (SKIPPED_DIRECTORIES.has(entry.name)) {
          continue;
        }
        await walk(absolute_path);
        continue;
      }

      if (!entry.isFile()) {
        continue;
      }

      const stats = directory_stats.get(top_level) ?? { file_count: 0, markdown_file_count: 0 };
      stats.file_count += 1;
      directory_stats.set(top_level, stats);

      if (key_file_candidates.has(relative_path) && !seen_key_files.has(relative_path)) {
        key_files.push(relative_path);
        seen_key_files.add(relative_path);
      }

      if (!is_markdown_file(entry.name)) {
        continue;
      }

      markdown_file_count += 1;
      stats.markdown_file_count += 1;
      directory_stats.set(top_level, stats);

      if (sample_paths.length < SAMPLE_LIMIT) {
        sample_paths.push(relative_path);
      }
    }
  }

  await walk(root);

  const directories = [...directory_stats.entries()]
    .filter(([directory]) => directory !== ".")
    .map(([directory, stats]) => ({
      path: directory,
      file_count: stats.file_count,
      markdown_file_count: stats.markdown_file_count,
    }))
    .sort((left, right) => compare_paths(left, right));

  const project_shape_hints = directories
    .map((directory) => directory.path)
    .filter((name) => name in CONTEXT_HEURISTICS);

  return {
    repo_root: root,
    markdown_file_count,
    key_files: key_files.sort((left, right) => left.localeCompare(right)),
    directories,
    sample_paths,
    project_shape_hints,
    truncated,
  };
}

export function build_draft_proposal(scan: RepoScan): DraftInitProposal {
  const paths = scan.directories
    .filter(
      (directory) => directory.markdown_file_count > 0 || directory.path in CONTEXT_HEURISTICS
    )
    .map((directory) => ({
      path: directory.path,
      annotation:
        CONTEXT_HEURISTICS[directory.path] ??
        `${directory.path} documentation and markdown content.`,
    }))
    .sort((left, right) => compare_paths(left, right));

  return draft_init_proposal_schema.parse({
    root: scan.repo_root,
    collection_key: collection_key_from_repo_root(scan.repo_root),
    glob_pattern: DEFAULT_GLOB_PATTERN,
    paths,
  });
}

export function build_init_prompt(scan: RepoScan, draft: DraftInitProposal): string {
  const key_files =
    scan.key_files.length > 0
      ? scan.key_files.map((file) => `- ${file}`).join("\n")
      : "- (none found)";
  const sample_paths =
    scan.sample_paths.length > 0
      ? scan.sample_paths.map((file) => `- ${file}`).join("\n")
      : "- (none found)";
  const project_shape =
    scan.project_shape_hints.length > 0
      ? scan.project_shape_hints.join(", ")
      : "(no common QMD heuristics matched)";
  const draft_paths =
    draft.paths.length > 0
      ? draft.paths.map((entry) => `- ${entry.path || "/"}: ${entry.annotation}`).join("\n")
      : "- (no path contexts proposed)";

  return [
    "You are helping onboard the current repository into the QMD extension workflow.",
    "Review the deterministic draft below, refine it if needed, and present the proposal back to the user.",
    "Do not reinvent the repo structure from scratch. Stay grounded in the scan facts.",
    "Do not call the qmd_init tool yet. Only call qmd_init after the user explicitly confirms the proposal in a later message.",
    "",
    "Repo scan summary:",
    `- repo root: ${scan.repo_root}`,
    `- markdown files: ${scan.markdown_file_count}`,
    `- project shape hints: ${project_shape}`,
    `- scan truncated: ${scan.truncated ? "yes" : "no"}`,
    "",
    "Key files:",
    key_files,
    "",
    "Sample markdown paths:",
    sample_paths,
    "",
    "Deterministic draft proposal:",
    `- root: ${draft.root}`,
    `- collection_key: ${draft.collection_key}`,
    `- glob_pattern: ${draft.glob_pattern}`,
    "- path contexts:",
    draft_paths,
  ].join("\n");
}

export async function normalize_init_proposal(
  input: ConfirmedInitProposal,
  expected_root: string
): Promise<NormalizedInitProposal> {
  const parsed = qmd_init_params_schema.safeParse(input);
  if (!parsed.success) {
    throw new InvalidInitProposalError(
      parsed.error.issues.map((issue) => issue.message).join("; "),
      parsed.error
    );
  }

  const normalized_root = await stat(parsed.data.root)
    .then(() => path.resolve(parsed.data.root))
    .catch(() => path.resolve(parsed.data.root));
  const expected_normalized_root = path.resolve(expected_root);
  if (normalized_root !== expected_normalized_root) {
    throw new InvalidInitProposalError(
      `Confirmed proposal root ${normalized_root} does not match the current repo root ${expected_normalized_root}.`
    );
  }

  const deduped = new Map<string, string>();
  for (const entry of parsed.data.paths) {
    const normalized_path = normalize_context_path(entry.path, expected_normalized_root);
    const annotation = normalize_annotation(entry.annotation);
    if (!annotation) {
      throw new InvalidInitProposalError(
        `Context path '${entry.path || "/"}' must have a non-empty annotation.`
      );
    }
    if (!deduped.has(normalized_path)) {
      deduped.set(normalized_path, annotation);
    }
  }

  const normalized = normalized_init_proposal_schema.parse({
    root: expected_normalized_root,
    collection_key: collection_key_from_repo_root(expected_normalized_root),
    glob_pattern: normalize_annotation(parsed.data.glob_pattern ?? DEFAULT_GLOB_PATTERN),
    paths: [...deduped.entries()]
      .map(([context_path, annotation]) => ({ path: context_path, annotation }))
      .sort((left, right) => compare_paths(left, right)),
  });

  return normalized;
}

export async function execute_init(
  proposal: NormalizedInitProposal,
  on_progress?: (message: string) => void
): Promise<InitResult> {
  on_progress?.(`Adding QMD collection ${proposal.collection_key}...`);
  await add_collection({
    collection_key: proposal.collection_key,
    repo_root: proposal.root,
    glob_pattern: proposal.glob_pattern,
  });

  on_progress?.(`Writing ${proposal.paths.length} QMD path contexts...`);
  await set_contexts(proposal.collection_key, proposal.paths);

  on_progress?.(`Updating QMD collection ${proposal.collection_key}...`);
  const update_result = await update_collection(proposal.collection_key, (info) => {
    on_progress?.(`Updating ${info.collection}: ${info.current}/${info.total} ${info.file}`);
  });

  // Index dot-path files that QMD's scanner skips (e.g. .pi/)
  const all_fs_paths = await scan_filesystem_paths(proposal.root);
  const dot_paths = all_fs_paths.filter(has_dot_segment);
  if (dot_paths.length > 0) {
    on_progress?.(`Indexing ${dot_paths.length} dot-path file(s) (.pi/, etc.)...`);
    await index_files(proposal.collection_key, proposal.root, dot_paths);
  }

  const needs_embedding = update_result.needsEmbedding > 0 || dot_paths.length > 0;
  let embed_result: QmdEmbedResult | null = null;
  if (needs_embedding) {
    on_progress?.(`Embedding pending document(s)...`);
    embed_result = await embed_pending((info) => {
      on_progress?.(`Embedding ${info.current}/${info.total}`);
    });
  }

  const now = new Date().toISOString();
  const existing_marker = await read_repo_marker(proposal.root).catch(() => null);
  const head_commit = await get_repo_head_commit(proposal.root);
  const marker: QmdRepoMarker = {
    schema_version: 1,
    repo_root: proposal.root,
    collection_key: proposal.collection_key,
    last_indexed_at: now,
    last_indexed_commit: head_commit ?? "",
    created_at: existing_marker?.created_at ?? now,
    extra_paths: dot_paths.length > 0 ? dot_paths : undefined,
  };
  await write_repo_marker(proposal.root, marker);

  return {
    repo_root: proposal.root,
    collection_key: proposal.collection_key,
    marker,
    update_result,
    embed_result,
  };
}
