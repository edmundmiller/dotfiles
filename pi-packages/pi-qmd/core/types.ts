/** Runtime schemas and shared types for repo binding, freshness, onboarding, and panel state. */

import { Type } from "@sinclair/typebox";
import { z } from "zod";

export const qmd_repo_marker_schema = z.object({
  schema_version: z.literal(1),
  repo_root: z.string().min(1),
  collection_key: z.string().min(1),
  last_indexed_at: z.string().min(1),
  last_indexed_commit: z.string(),
  created_at: z.string().min(1),
  /** Filesystem paths with dot-segments (e.g. .pi/) that the user explicitly
   *  added to the index. QMD's scanner skips dot-dirs, so these need to be
   *  re-indexed after every `update_collection()` call. */
  extra_paths: z.array(z.string()).optional(),
});

export type QmdRepoMarker = z.infer<typeof qmd_repo_marker_schema>;

export const repo_binding_result_schema = z.discriminatedUnion("status", [
  z.object({
    status: z.literal("indexed"),
    repo_root: z.string().min(1),
    collection_key: z.string().min(1),
    marker: qmd_repo_marker_schema.nullable(),
    source: z.enum(["marker", "store"]),
  }),
  z.object({
    status: z.literal("not_indexed"),
    repo_root: z.string().min(1),
    marker: qmd_repo_marker_schema.nullable().optional(),
  }),
  z.object({
    status: z.literal("unavailable"),
    repo_root: z.string().min(1).optional(),
    reason: z.string().min(1),
  }),
]);

export type RepoBindingResult = z.infer<typeof repo_binding_result_schema>;
export type RepoBinding = Extract<RepoBindingResult, { status: "indexed" }>;

export const freshness_result_schema = z.discriminatedUnion("status", [
  z.object({ status: z.literal("fresh") }),
  z.object({
    status: z.literal("stale"),
    changed_paths: z.array(z.string()),
    changed_count: z.number().int().nonnegative(),
  }),
  z.object({
    status: z.literal("unknown"),
    reason: z.string().min(1),
  }),
]);

export type FreshnessResult = z.infer<typeof freshness_result_schema>;

export const repo_scan_directory_schema = z.object({
  path: z.string(),
  file_count: z.number().int().nonnegative(),
  markdown_file_count: z.number().int().nonnegative(),
});

export const repo_scan_schema = z.object({
  repo_root: z.string().min(1),
  markdown_file_count: z.number().int().nonnegative(),
  key_files: z.array(z.string()),
  directories: z.array(repo_scan_directory_schema),
  sample_paths: z.array(z.string()),
  project_shape_hints: z.array(z.string()),
  truncated: z.boolean(),
});

export type RepoScan = z.infer<typeof repo_scan_schema>;

export const proposal_path_schema = z.object({
  path: z.string(),
  annotation: z.string(),
});

export type ProposalPath = z.infer<typeof proposal_path_schema>;

export const draft_init_proposal_schema = z.object({
  root: z.string().min(1),
  collection_key: z.string().min(1),
  glob_pattern: z.string().min(1).default("**/*.md"),
  paths: z.array(proposal_path_schema),
});

export type DraftInitProposal = z.infer<typeof draft_init_proposal_schema>;

export const qmd_init_params_schema = z.object({
  root: z.string().min(1),
  paths: z.array(proposal_path_schema),
  glob_pattern: z.string().min(1).optional(),
});

export type ConfirmedInitProposal = z.infer<typeof qmd_init_params_schema>;

export const normalized_init_proposal_schema = z.object({
  root: z.string().min(1),
  collection_key: z.string().min(1),
  glob_pattern: z.string().min(1),
  paths: z.array(
    z.object({
      path: z.string(),
      annotation: z.string().min(1),
    })
  ),
});

export type NormalizedInitProposal = z.infer<typeof normalized_init_proposal_schema>;

export const QmdInitParams = Type.Object({
  root: Type.String({ description: "Absolute repo root" }),
  paths: Type.Array(
    Type.Object({
      path: Type.String({ description: "Repo-relative path prefix, e.g. 'docs'" }),
      annotation: Type.String({ description: "Human-written context for that path" }),
    })
  ),
  glob_pattern: Type.Optional(Type.String({ description: "Defaults to **/*.md" })),
});

export interface QmdCollectionRecord {
  name: string;
  pwd: string;
  glob_pattern: string;
  doc_count: number;
  active_count: number;
  last_modified: string | null;
  includeByDefault: boolean;
}

export interface QmdContextRecord {
  collection: string;
  path: string;
  context: string;
}

export interface QmdUpdateResult {
  collections: number;
  indexed: number;
  updated: number;
  unchanged: number;
  removed: number;
  needsEmbedding: number;
}

export interface QmdEmbedResult {
  total: number;
  embedded: number;
  skipped: number;
}

export interface QmdIndexStatus {
  totalDocuments: number;
  needsEmbedding: number;
  hasVectorIndex: boolean;
  collections: Array<{
    name: string;
    path: string | null;
    pattern: string | null;
    documentCount: number;
  }>;
}

export interface InitResult {
  repo_root: string;
  collection_key: string;
  marker: QmdRepoMarker;
  update_result: QmdUpdateResult;
  embed_result: QmdEmbedResult | null;
}
