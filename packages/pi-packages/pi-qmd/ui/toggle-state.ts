/** Pure pending-toggle state machine for file inclusion changes in the QMD panel. */

import { collect_file_paths, type FileTreeNode } from "./data.js";

/**
 * Manages pending toggle state for file index inclusion.
 * Pure data structure — no UI dependency.
 */
export class ToggleState {
  readonly indexed_set: Set<string>;
  readonly pending_adds: Set<string> = new Set();
  readonly pending_removes: Set<string> = new Set();

  constructor(indexed_paths: string[]) {
    this.indexed_set = new Set(indexed_paths);
  }

  /** Check if a file is effectively indexed (considering pending changes) */
  is_effectively_indexed(file_path: string): boolean {
    if (this.pending_adds.has(file_path)) return true;
    if (this.pending_removes.has(file_path)) return false;
    return this.indexed_set.has(file_path);
  }

  /** Set pending state for a single file */
  set_file_state(file_path: string, should_be_indexed: boolean): void {
    const originally_indexed = this.indexed_set.has(file_path);

    if (should_be_indexed === originally_indexed) {
      // No change needed — clear any pending state
      this.pending_adds.delete(file_path);
      this.pending_removes.delete(file_path);
    } else if (should_be_indexed) {
      // Want indexed, but currently not → pending add
      this.pending_removes.delete(file_path);
      this.pending_adds.add(file_path);
    } else {
      // Want not indexed, but currently is → pending remove
      this.pending_adds.delete(file_path);
      this.pending_removes.add(file_path);
    }
  }

  /** Toggle a single file's inclusion */
  toggle_file(file_path: string): void {
    this.set_file_state(file_path, !this.is_effectively_indexed(file_path));
  }

  /** Toggle a directory node — if any descendant is included, remove all; otherwise add all */
  toggle_dir(node: FileTreeNode): void {
    const descendant_paths = collect_file_paths(node);
    const any_included = descendant_paths.some((p) => this.is_effectively_indexed(p));
    for (const p of descendant_paths) {
      this.set_file_state(p, !any_included);
    }
  }

  /** Toggle a tree node (dispatches to file or dir) */
  toggle_node(node: FileTreeNode): void {
    if (node.is_dir) {
      this.toggle_dir(node);
    } else {
      this.toggle_file(node.path);
    }
  }

  /** Whether there are any pending changes */
  has_pending(): boolean {
    return this.pending_adds.size > 0 || this.pending_removes.size > 0;
  }

  /** Total pending change count */
  pending_count(): number {
    return this.pending_adds.size + this.pending_removes.size;
  }

  /** Reset pending state */
  clear(): void {
    this.pending_adds.clear();
    this.pending_removes.clear();
  }
}
