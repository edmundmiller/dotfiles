/** Repo-root resolution plus .pi/qmd.json marker read/write and binding reconciliation. */

import { execFile as exec_file_callback } from "node:child_process";
import { mkdir, readFile, realpath, writeFile } from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";
import { CollectionBindingMismatchError, get_error_message } from "../core/errors.js";
import { list_collections } from "../core/qmd-store.js";
import {
  type QmdCollectionRecord,
  type QmdRepoMarker,
  qmd_repo_marker_schema,
  type RepoBindingResult,
} from "../core/types.js";

const exec_file = promisify(exec_file_callback);
const QMD_MARKER_RELATIVE_PATH = path.join(".pi", "qmd.json");

async function safe_realpath(value: string): Promise<string> {
  try {
    return await realpath(value);
  } catch {
    return path.resolve(value);
  }
}

export async function resolve_repo_root(cwd: string): Promise<string> {
  const normalized_cwd = await safe_realpath(cwd);

  try {
    const { stdout } = await exec_file("git", [
      "-C",
      normalized_cwd,
      "rev-parse",
      "--show-toplevel",
    ]);
    const repo_root = stdout.trim();
    if (!repo_root) {
      return normalized_cwd;
    }
    return safe_realpath(repo_root);
  } catch {
    return normalized_cwd;
  }
}

function get_marker_path(repo_root: string): string {
  return path.join(repo_root, QMD_MARKER_RELATIVE_PATH);
}

export function collection_key_from_repo_root(repo_root: string): string {
  return path.basename(repo_root);
}

export async function read_repo_marker(cwd: string): Promise<QmdRepoMarker | null> {
  const repo_root = await resolve_repo_root(cwd);
  const marker_path = get_marker_path(repo_root);

  let raw: string;
  try {
    raw = await readFile(marker_path, "utf8");
  } catch (error: any) {
    if (error?.code === "ENOENT") {
      return null;
    }
    throw error;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    throw new CollectionBindingMismatchError(
      `${QMD_MARKER_RELATIVE_PATH} exists at ${repo_root} but is not valid JSON. Delete or repair the marker before relying on it.`,
      error
    );
  }

  const result = qmd_repo_marker_schema.safeParse(parsed);
  if (!result.success) {
    throw new CollectionBindingMismatchError(
      `${QMD_MARKER_RELATIVE_PATH} exists at ${repo_root} but does not match schema_version 1. ${result.error.issues[0]?.message ?? "The marker is invalid."}`,
      result.error
    );
  }

  return result.data;
}

export async function write_repo_marker(cwd: string, marker: QmdRepoMarker): Promise<void> {
  const repo_root = await resolve_repo_root(cwd);
  const marker_path = get_marker_path(repo_root);
  await mkdir(path.dirname(marker_path), { recursive: true });
  await writeFile(marker_path, `${JSON.stringify(marker, null, 2)}\n`, "utf8");
}

function is_collection_for_repo(collection: QmdCollectionRecord, repo_root: string): boolean {
  return collection.pwd === repo_root;
}

export async function detect_repo_binding(cwd: string): Promise<RepoBindingResult> {
  const repo_root = await resolve_repo_root(cwd);

  let marker: QmdRepoMarker | null = null;
  try {
    marker = await read_repo_marker(repo_root);
  } catch {
    // Corrupt marker — treat as absent.
  }

  let collections: QmdCollectionRecord[];
  try {
    collections = await list_collections();
  } catch (error) {
    return {
      status: "unavailable",
      repo_root,
      reason: get_error_message(error),
    };
  }

  const marker_collection = marker
    ? (collections.find((collection) => collection.name === marker.collection_key) ?? null)
    : null;
  const repo_collection =
    collections.find((collection) => is_collection_for_repo(collection, repo_root)) ?? null;

  if (
    marker &&
    marker_collection &&
    is_collection_for_repo(marker_collection, repo_root) &&
    marker.collection_key === marker_collection.name
  ) {
    return {
      status: "indexed",
      repo_root,
      collection_key: marker_collection.name,
      marker,
      source: "marker",
    };
  }

  if (repo_collection) {
    return {
      status: "indexed",
      repo_root,
      collection_key: repo_collection.name,
      marker,
      source: "store",
    };
  }

  return {
    status: "not_indexed",
    repo_root,
    marker: marker ?? undefined,
  };
}
