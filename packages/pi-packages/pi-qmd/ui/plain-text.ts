/** Plain-text summary renderer for QMD status when no interactive UI is available. */

import type { QmdPanelSnapshot } from "./data.js";
import { format_relative_time } from "./data.js";

export function build_plain_text_summary(snapshot: QmdPanelSnapshot): string {
  const lines: string[] = [];

  if (snapshot.binding_status === "unavailable") {
    lines.push("QMD Index: unavailable");
    if (snapshot.error_reason) {
      lines.push(snapshot.error_reason);
    }
    return lines.join("\n");
  }

  if (snapshot.binding_status === "not_indexed" && !snapshot.collection_key) {
    lines.push("QMD Index: not indexed");
    if (snapshot.repo_root) {
      lines.push(`repo: ${snapshot.repo_root}`);
    }
    if (snapshot.collections.length > 0) {
      lines.push(
        `available collections: ${snapshot.collections.length} (use /qmd in TUI to inspect)`
      );
    }
    lines.push("Run /qmd init to onboard this repository.");
    return lines.join("\n");
  }

  const scope_badge =
    snapshot.selected_collection_scope === "bound"
      ? "bound"
      : snapshot.selected_collection_scope === "external"
        ? "external · readonly"
        : "no selection";
  const freshness_badge =
    snapshot.selected_collection_scope !== "bound"
      ? "freshness n/a"
      : snapshot.freshness_status === "fresh"
        ? "fresh"
        : snapshot.freshness_status === "stale"
          ? `${snapshot.stale_count} stale`
          : "freshness unknown";

  lines.push(`QMD Index: ${snapshot.binding_status} · ${scope_badge} · ${freshness_badge}`);
  lines.push(
    [
      snapshot.collection_key ? `selected: ${snapshot.collection_key}` : null,
      snapshot.bound_collection_key ? `bound: ${snapshot.bound_collection_key}` : null,
      snapshot.glob_pattern,
      `${snapshot.total_documents} docs`,
    ]
      .filter(Boolean)
      .join("  ·  ")
  );

  if (snapshot.last_indexed_at) {
    const parts = [`last indexed: ${format_relative_time(snapshot.last_indexed_at)}`];
    if (snapshot.last_indexed_commit) {
      parts.push(snapshot.last_indexed_commit.slice(0, 7));
    }
    lines.push(parts.join("  ·  "));
  }

  lines.push("");
  lines.push(`documents: ${snapshot.total_documents}`);
  lines.push(`vector index: ${snapshot.has_vector_index ? "yes" : "no"}`);
  lines.push(`needs embed: ${snapshot.needs_embedding}`);
  if (snapshot.read_only_reason) {
    lines.push(`mode: readonly (${snapshot.read_only_reason})`);
  }

  if (snapshot.collections.length > 0) {
    lines.push("");
    lines.push(`Collections (${snapshot.collections.length}):`);
    for (const collection of snapshot.collections.slice(0, 12)) {
      const marker = [
        collection.key === snapshot.collection_key ? "selected" : null,
        collection.is_bound_collection ? "bound" : null,
      ]
        .filter(Boolean)
        .join(", ");
      const suffix = marker ? ` [${marker}]` : "";
      lines.push(`  ${collection.key}${suffix}`);
    }
    if (snapshot.collections.length > 12) {
      lines.push(`  ... +${snapshot.collections.length - 12} more`);
    }
  }

  if (snapshot.contexts.length > 0) {
    lines.push("");
    lines.push(`Contexts (${snapshot.contexts.length}):`);
    for (const ctx of snapshot.contexts) {
      lines.push(`  ${ctx.path}  ${ctx.annotation}`);
    }
  }

  if (snapshot.stale_count > 0) {
    lines.push("");
    lines.push(`Stale (${snapshot.stale_count}):`);
    for (const p of snapshot.stale_paths) {
      lines.push(`  ${p}`);
    }
  }

  return lines.join("\n");
}
