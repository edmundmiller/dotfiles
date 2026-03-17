/** QMD store wrapper plus filesystem/index helpers used by the Pi extension. */

import { createHash } from "node:crypto";
import { stat as fsStat, mkdir, readdir, readFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createStore, type HybridQueryResult, type QMDStore, type SearchResult } from "@tobilu/qmd";
import { QmdUnavailableError } from "./errors.js";
import type {
  QmdCollectionRecord,
  QmdContextRecord,
  QmdEmbedResult,
  QmdIndexStatus,
  QmdUpdateResult,
} from "./types.js";

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
const SCAN_LIMIT = 6000;

/**
 * Re-implementation of QMD's internal handelize function.
 * Normalizes filesystem paths to the format QMD stores in its database.
 * Must match the behavior of the handelize() in @tobilu/qmd/dist/store.js.
 */
export function handelize_path(file_path: string): string {
  return file_path
    .toLowerCase()
    .split("/")
    .map((segment, idx, arr) => {
      const is_last = idx === arr.length - 1;
      if (is_last) {
        const ext_match = segment.match(/(\.[a-z0-9]+)$/i);
        const ext = ext_match ? ext_match[1] : "";
        const name_without_ext = ext ? segment.slice(0, -ext.length) : segment;
        const cleaned = name_without_ext.replace(/[^a-z0-9$]+/gu, "-").replace(/^-+|-+$/g, "");
        return cleaned + ext;
      }
      return segment.replace(/[^a-z0-9$]+/gu, "-").replace(/^-+|-+$/g, "");
    })
    .filter(Boolean)
    .join("/");
}

let store_promise: Promise<QMDStore> | null = null;

function get_default_qmd_db_path(): string {
  const cache_root = process.env.XDG_CACHE_HOME || path.join(os.homedir(), ".cache");
  return path.join(cache_root, "qmd", "index.sqlite");
}

async function open_store(): Promise<QMDStore> {
  const db_path = get_default_qmd_db_path();
  await mkdir(path.dirname(db_path), { recursive: true });
  return createStore({ dbPath: db_path });
}

async function with_store<T>(action: string, fn: (store: QMDStore) => Promise<T>): Promise<T> {
  try {
    store_promise ??= open_store();
    const store = await store_promise;
    return await fn(store);
  } catch (error) {
    store_promise = null;
    throw new QmdUnavailableError(action, error);
  }
}

export async function close_store(): Promise<void> {
  if (!store_promise) {
    return;
  }

  try {
    const store = await store_promise;
    await store.close();
  } finally {
    store_promise = null;
  }
}

export async function list_collections(): Promise<QmdCollectionRecord[]> {
  return with_store("list QMD collections", async (store) => store.listCollections());
}

export async function add_collection(params: {
  collection_key: string;
  repo_root: string;
  glob_pattern?: string;
}): Promise<void> {
  await with_store(`add QMD collection '${params.collection_key}'`, async (store) => {
    await store.addCollection(params.collection_key, {
      path: params.repo_root,
      pattern: params.glob_pattern ?? "**/*.md",
    });
  });
}

export async function set_contexts(
  collection_key: string,
  paths: Array<{ path: string; annotation: string }>
): Promise<void> {
  await with_store(`set QMD contexts for '${collection_key}'`, async (store) => {
    const current = (await store.listContexts()).filter(
      (context) => context.collection === collection_key
    );
    const desired = new Map(paths.map((entry) => [entry.path, entry.annotation]));

    for (const context of current) {
      if (!desired.has(context.path)) {
        await store.removeContext(collection_key, context.path);
      }
    }

    for (const entry of paths) {
      await store.addContext(collection_key, entry.path, entry.annotation);
    }
  });
}

export async function list_contexts(): Promise<QmdContextRecord[]> {
  return with_store("list QMD contexts", async (store) => store.listContexts());
}

export async function update_collection(
  collection_key: string,
  on_progress?: (info: { collection: string; file: string; current: number; total: number }) => void
): Promise<QmdUpdateResult> {
  return with_store(`update QMD collection '${collection_key}'`, async (store) =>
    store.update({
      collections: [collection_key],
      onProgress: on_progress,
    })
  );
}

export async function embed_pending(
  on_progress?: (info: { current: number; total: number }) => void
): Promise<QmdEmbedResult | null> {
  return with_store("generate pending QMD embeddings", async (store) => {
    const status = await store.getStatus();
    if (status.needsEmbedding <= 0) {
      return null;
    }

    const result = await store.embed({
      onProgress: on_progress
        ? (info) => {
            on_progress({
              current: info.chunksEmbedded,
              total: info.totalChunks,
            });
          }
        : undefined,
    });

    return {
      total: result.docsProcessed,
      embedded: result.chunksEmbedded,
      skipped: result.errors,
    };
  });
}

function read_collection_document_count(collection: unknown): number {
  if (typeof collection !== "object" || collection === null) {
    return 0;
  }

  const documents = Reflect.get(collection, "documents");
  if (typeof documents === "number") {
    return documents;
  }

  const document_count = Reflect.get(collection, "documentCount");
  if (typeof document_count === "number") {
    return document_count;
  }

  const legacy_document_count = Reflect.get(collection, "doc_count");
  if (typeof legacy_document_count === "number") {
    return legacy_document_count;
  }

  return 0;
}

export async function get_status(): Promise<QmdIndexStatus> {
  return with_store("read QMD index status", async (store) => {
    const status = await store.getStatus();
    return {
      totalDocuments: status.totalDocuments,
      needsEmbedding: status.needsEmbedding,
      hasVectorIndex: status.hasVectorIndex,
      collections: status.collections.map((collection) => ({
        name: collection.name,
        path: collection.path,
        pattern: collection.pattern,
        documentCount: read_collection_document_count(collection),
      })),
    };
  });
}

/**
 * Returns handlized paths as stored in the QMD database.
 * These need to be mapped back to filesystem paths for display.
 */
export async function get_active_document_paths(collection_key: string): Promise<string[]> {
  return with_store(`get active document paths for '${collection_key}'`, async (store) => {
    return store.internal.getActiveDocumentPaths(collection_key);
  });
}

export interface QmdIndexHealthInfo {
  needs_embedding: number;
  total_docs: number;
  days_stale: number | null;
}

export async function get_index_health(): Promise<QmdIndexHealthInfo> {
  return with_store("get QMD index health", async (store) => {
    const health = await store.getIndexHealth();
    return {
      needs_embedding: health.needsEmbedding,
      total_docs: health.totalDocs,
      days_stale: health.daysStale,
    };
  });
}

/**
 * Deactivate a document using its filesystem-relative path.
 * Converts to handlized path for the QMD store.
 */
export async function deactivate_document(collection_key: string, fs_path: string): Promise<void> {
  const qmd_path = handelize_path(fs_path);
  await with_store(`deactivate document '${fs_path}' in '${collection_key}'`, async (store) => {
    store.internal.deactivateDocument(collection_key, qmd_path);
  });
}

/**
 * Directly index specific files into the QMD store.
 * Reads each file, hashes content, and inserts via internal store APIs.
 * Works for any file path including dotfiles that QMD's glob scanner skips.
 */
export async function index_files(
  collection_key: string,
  repo_root: string,
  fs_paths: string[]
): Promise<{ indexed: number; updated: number; skipped: number }> {
  return with_store(`index ${fs_paths.length} files into '${collection_key}'`, async (store) => {
    const now = new Date().toISOString();
    let indexed = 0;
    let updated = 0;
    let skipped = 0;

    for (const fs_path of fs_paths) {
      const absolute_path = path.join(repo_root, fs_path);
      const qmd_path = handelize_path(fs_path);

      let content: string;
      try {
        content = await readFile(absolute_path, "utf-8");
      } catch {
        skipped++;
        continue;
      }

      if (!content.trim()) {
        skipped++;
        continue;
      }

      // Hash content (same algo as QMD uses internally)
      const hash = hash_content(content);
      const title = extract_title(content, fs_path);

      const existing = store.internal.findActiveDocument(collection_key, qmd_path);
      if (existing) {
        if (existing.hash === hash) {
          skipped++;
        } else {
          store.internal.insertContent(hash, content, now);
          let modified_at = now;
          try {
            const st = await fsStat(absolute_path);
            modified_at = st.mtime.toISOString();
          } catch {
            // use now
          }
          store.internal.updateDocument(existing.id, title, hash, modified_at);
          updated++;
        }
      } else {
        store.internal.insertContent(hash, content, now);
        let created_at = now;
        let modified_at = now;
        try {
          const st = await fsStat(absolute_path);
          created_at = st.birthtime.toISOString();
          modified_at = st.mtime.toISOString();
        } catch {
          // use now
        }
        store.internal.insertDocument(
          collection_key,
          qmd_path,
          title,
          hash,
          created_at,
          modified_at
        );
        indexed++;
      }
    }

    return { indexed, updated, skipped };
  });
}

// ── Document content ────────────────────────────────────────

export async function get_document_content(
  virtual_path: string
): Promise<{ content: string; title: string } | null> {
  return with_store("get document content", async (store) => {
    const doc = store.internal.findDocument(virtual_path, { includeBody: true });
    if (!doc || "error" in doc) return null;
    return { content: doc.body ?? "", title: doc.title };
  });
}

// ── Search wrappers ─────────────────────────────────────────

export async function search_lex(
  query: string,
  collection: string,
  limit = 20
): Promise<SearchResult[]> {
  return with_store("search (lex)", async (store) => {
    return store.searchLex(query, { collection, limit });
  });
}

export async function search_vector(
  query: string,
  collection: string,
  limit = 20
): Promise<SearchResult[]> {
  return with_store("search (vector)", async (store) => {
    return store.searchVector(query, { collection, limit });
  });
}

export async function search_hybrid(
  query: string,
  collection: string,
  limit = 20
): Promise<HybridQueryResult[]> {
  return with_store("search (hybrid)", async (store) => {
    return store.search({ query, collection, limit });
  });
}

/** Content hash matching QMD's internal hashContent — SHA-256 hex via Node crypto */
function hash_content(content: string): string {
  return createHash("sha256").update(content).digest("hex");
}

/** Extract title matching QMD's internal extractor — first h1 or h2, or filename */
function extract_title(content: string, filename: string): string {
  const match = content.match(/^##?\s+(.+)$/m);
  if (match) return match[1].trim();
  const base = filename.split("/").pop() ?? filename;
  return base.replace(/\.mdx?$/i, "");
}

/** Returns true if any path segment starts with "." (e.g. ".pi/foo.md") */
export function has_dot_segment(fs_path: string): boolean {
  return fs_path.split("/").some((seg) => seg.startsWith("."));
}

function is_markdown_file(file_name: string): boolean {
  return /\.mdx?$/iu.test(file_name);
}

function to_posix_relative(repo_root: string, absolute_path: string): string {
  return path.relative(repo_root, absolute_path).split(path.sep).join("/");
}

/**
 * Walk the repo filesystem and return all markdown paths.
 * Includes dot-prefixed directories (e.g. .pi/) — these are shown in the
 * file tree so users can opt in to indexing them. QMD's reindexer skips
 * dot-dirs, so dot-path files are persisted via the marker's `extra_paths`
 * and re-indexed after every `update_collection()`.
 * Skips common non-content directories (.git, node_modules, etc.).
 */
export async function scan_filesystem_paths(
  repo_root: string,
  _glob_pattern?: string
): Promise<string[]> {
  const results: string[] = [];
  let visited = 0;

  async function walk(directory: string): Promise<void> {
    if (visited >= SCAN_LIMIT) return;

    let entries;
    try {
      entries = await readdir(directory, { withFileTypes: true, encoding: "utf8" });
    } catch {
      return;
    }

    for (const entry of entries) {
      if (visited >= SCAN_LIMIT) return;
      visited += 1;

      const absolute_path = path.join(directory, entry.name);

      if (entry.isDirectory()) {
        if (SKIPPED_DIRECTORIES.has(entry.name)) continue;
        await walk(absolute_path);
        continue;
      }

      if (entry.isFile() && is_markdown_file(entry.name)) {
        results.push(to_posix_relative(repo_root, absolute_path));
      }
    }
  }

  await walk(repo_root);
  results.sort();
  return results;
}
