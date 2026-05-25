import { beforeEach, describe, expect, it, vi } from "vitest";
import type { FreshnessResult, RepoBindingResult } from "../../core/types.js";
import {
  build_file_tree,
  build_qmd_panel_snapshot,
  flatten_tree,
  format_relative_time,
  group_paths_by_directory,
  wrap_text,
} from "../../ui/data.js";
import { build_plain_text_summary } from "../../ui/plain-text.js";

// ── Mock store ──────────────────────────────────────────────

vi.mock("../../core/qmd-store.js", async () => {
  const actual =
    await vi.importActual<typeof import("../../core/qmd-store.js")>("../../core/qmd-store.js");
  return {
    get_status: vi.fn(() =>
      Promise.resolve({
        totalDocuments: 154,
        needsEmbedding: 0,
        hasVectorIndex: true,
        collections: [
          { name: "agents", path: "/repo", pattern: "**/*.md", documentCount: 142 },
          { name: "other", path: "/tmp/other", pattern: "notes/**/*.md", documentCount: 12 },
        ],
      })
    ),
    list_contexts: vi.fn(() =>
      Promise.resolve([
        { collection: "agents", path: "docs/", context: "Architecture docs" },
        { collection: "agents", path: "extensions/", context: "Pi extensions" },
        { collection: "other", path: "lib/", context: "Library code" },
      ])
    ),
    // QMD stores handlized paths (lowercased, cleaned)
    get_active_document_paths: vi.fn((collection_key: string) =>
      collection_key === "other"
        ? Promise.resolve(["notes/ideas.md", "design/decision-log.md"])
        : Promise.resolve(["docs/architecture.md", "docs/quality.md", "extensions/qmd/readme.md"])
    ),
    get_index_health: vi.fn(() =>
      Promise.resolve({ needs_embedding: 0, total_docs: 154, days_stale: null })
    ),
    scan_filesystem_paths: vi.fn(() =>
      Promise.resolve([
        "docs/ARCHITECTURE.md",
        "docs/QUALITY.md",
        "extensions/qmd/README.md",
        "README.md",
        "CHANGELOG.md",
      ])
    ),
    // Use real handelize_path so the mapping works correctly in tests
    handelize_path: actual.handelize_path,
  };
});

// ── Helpers ─────────────────────────────────────────────────

function indexed_binding(
  overrides?: Partial<Extract<RepoBindingResult, { status: "indexed" }>>
): RepoBindingResult {
  return {
    status: "indexed",
    repo_root: "/repo",
    collection_key: "agents",
    source: "marker",
    marker: {
      schema_version: 1,
      repo_root: "/repo",
      collection_key: "agents",
      last_indexed_at: "2026-03-13T12:00:00Z",
      last_indexed_commit: "abc1234",
      created_at: "2026-03-01T00:00:00Z",
    },
    ...overrides,
  };
}

const fresh_result: FreshnessResult = { status: "fresh" };

const stale_result: FreshnessResult = {
  status: "stale",
  changed_paths: ["docs/ARCHITECTURE.md", "extensions/qmd/README.md"],
  changed_count: 2,
};

// ── Tests ───────────────────────────────────────────────────

describe("build_qmd_panel_snapshot", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("indexed + fresh → full snapshot", async () => {
    const snap = await build_qmd_panel_snapshot("/repo", indexed_binding(), fresh_result);

    expect(snap.binding_status).toBe("indexed");
    expect(snap.repo_root).toBe("/repo");
    expect(snap.collection_key).toBe("agents");
    expect(snap.bound_collection_key).toBe("agents");
    expect(snap.selected_collection_scope).toBe("bound");
    expect(snap.supports_update_action).toBe(true);
    expect(snap.supports_file_toggling).toBe(true);
    expect(snap.binding_source).toBe("marker");
    expect(snap.freshness_status).toBe("fresh");
    expect(snap.stale_paths).toEqual([]);
    expect(snap.stale_count).toBe(0);
    expect(snap.total_documents).toBe(142);
    expect(snap.needs_embedding).toBe(0);
    expect(snap.has_vector_index).toBe(true);
    expect(snap.glob_pattern).toBe("**/*.md");
    expect(snap.last_indexed_at).toBe("2026-03-13T12:00:00Z");
    expect(snap.last_indexed_commit).toBe("abc1234");
    expect(snap.contexts).toHaveLength(2); // only "agents" collection
    expect(snap.contexts[0]).toEqual({ path: "docs/", annotation: "Architecture docs" });
    expect(snap.collections).toHaveLength(2);
    expect(snap.indexed_paths).toHaveLength(3);
    expect(snap.filesystem_paths).toHaveLength(5);
    expect(snap.file_paths_source).toBe("filesystem");
    expect(snap.error_reason).toBeNull();
  });

  it("indexed + stale → stale paths populated", async () => {
    const snap = await build_qmd_panel_snapshot("/repo", indexed_binding(), stale_result);

    expect(snap.freshness_status).toBe("stale");
    expect(snap.stale_paths).toEqual(["docs/ARCHITECTURE.md", "extensions/qmd/README.md"]);
    expect(snap.stale_count).toBe(2);
  });

  it("indexed + unknown freshness → null freshness", async () => {
    const snap = await build_qmd_panel_snapshot("/repo", indexed_binding(), undefined);

    expect(snap.binding_status).toBe("indexed");
    expect(snap.freshness_status).toBeNull();
  });

  it("indexed + external selected collection → readonly external snapshot", async () => {
    const snap = await build_qmd_panel_snapshot("/repo", indexed_binding(), stale_result, "other");

    expect(snap.collection_key).toBe("other");
    expect(snap.bound_collection_key).toBe("agents");
    expect(snap.selected_collection_scope).toBe("external");
    expect(snap.supports_update_action).toBe(false);
    expect(snap.supports_file_toggling).toBe(false);
    expect(snap.freshness_status).toBeNull();
    expect(snap.stale_count).toBe(0);
    expect(snap.contexts).toEqual([{ path: "lib/", annotation: "Library code" }]);
    expect(snap.indexed_paths).toEqual(["notes/ideas.md", "design/decision-log.md"]);
    expect(snap.filesystem_paths).toEqual(["notes/ideas.md", "design/decision-log.md"]);
    expect(snap.file_paths_source).toBe("qmd");
  });

  it("missing selected key falls back to bound collection", async () => {
    const snap = await build_qmd_panel_snapshot(
      "/repo",
      indexed_binding(),
      fresh_result,
      "does-not-exist"
    );

    expect(snap.collection_key).toBe("agents");
    expect(snap.selected_collection_scope).toBe("bound");
    expect(snap.supports_update_action).toBe(true);
  });

  it("not indexed → falls back to first available external collection", async () => {
    const binding: RepoBindingResult = {
      status: "not_indexed",
      repo_root: "/repo",
    };
    const snap = await build_qmd_panel_snapshot("/repo", binding, undefined);

    expect(snap.binding_status).toBe("not_indexed");
    expect(snap.repo_root).toBe("/repo");
    expect(snap.collection_key).toBe("agents");
    expect(snap.bound_collection_key).toBeNull();
    expect(snap.selected_collection_scope).toBe("external");
    expect(snap.supports_update_action).toBe(false);
    expect(snap.supports_file_toggling).toBe(false);
    expect(snap.total_documents).toBe(142);
    expect(snap.contexts).toHaveLength(2);
    expect(snap.indexed_paths).toEqual([
      "docs/architecture.md",
      "docs/quality.md",
      "extensions/qmd/readme.md",
    ]);
    expect(snap.filesystem_paths).toEqual([
      "docs/architecture.md",
      "docs/quality.md",
      "extensions/qmd/readme.md",
    ]);
    expect(snap.file_paths_source).toBe("qmd");
  });

  it("unavailable → error reason captured", async () => {
    const { get_status } = await import("../../core/qmd-store.js");
    const binding: RepoBindingResult = {
      status: "unavailable",
      reason: "QMD store could not be opened",
    };
    const snap = await build_qmd_panel_snapshot("/repo", binding, undefined);

    expect(snap.binding_status).toBe("unavailable");
    expect(snap.error_reason).toBe("QMD store could not be opened");
    expect(snap.collection_key).toBeNull();
    expect(get_status).not.toHaveBeenCalled();
  });

  it("store error during snapshot → falls back to unavailable", async () => {
    const { get_status } = await import("../../core/qmd-store.js");
    vi.mocked(get_status).mockRejectedValueOnce(new Error("db locked"));
    const snap = await build_qmd_panel_snapshot("/repo", indexed_binding(), fresh_result);

    expect(snap.binding_status).toBe("unavailable");
    expect(snap.error_reason).toBe("Failed to read QMD store data.");
  });

  it("plain-text summary marks readonly external selection", async () => {
    const snap = await build_qmd_panel_snapshot("/repo", indexed_binding(), fresh_result, "other");
    const summary = build_plain_text_summary(snap);

    expect(summary).toContain("external · readonly");
    expect(summary).toContain("mode: readonly");
    expect(summary).toContain("[selected]");
  });
});

describe("format_relative_time", () => {
  it("just now for very recent timestamps", () => {
    const now = new Date().toISOString();
    expect(format_relative_time(now)).toBe("just now");
  });

  it("minutes ago", () => {
    const ten_min_ago = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    expect(format_relative_time(ten_min_ago)).toBe("10m ago");
  });

  it("hours ago", () => {
    const two_hours_ago = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
    expect(format_relative_time(two_hours_ago)).toBe("2h ago");
  });

  it("days ago", () => {
    const three_days_ago = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString();
    expect(format_relative_time(three_days_ago)).toBe("3d ago");
  });

  it("months ago", () => {
    const sixty_days_ago = new Date(Date.now() - 60 * 24 * 60 * 60 * 1000).toISOString();
    expect(format_relative_time(sixty_days_ago)).toBe("2mo ago");
  });

  it("invalid date returns unknown", () => {
    expect(format_relative_time("not-a-date")).toBe("unknown");
  });

  it("future date returns just now", () => {
    const future = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    expect(format_relative_time(future)).toBe("just now");
  });
});

describe("group_paths_by_directory", () => {
  it("groups by top-level directory", () => {
    const paths = ["docs/A.md", "docs/B.md", "extensions/qmd/README.md", "README.md"];
    const groups = group_paths_by_directory(paths);

    expect(groups.get("docs")).toEqual(["docs/A.md", "docs/B.md"]);
    expect(groups.get("extensions")).toEqual(["extensions/qmd/README.md"]);
    expect(groups.get(".")).toEqual(["README.md"]);
  });

  it("empty array returns empty map", () => {
    const groups = group_paths_by_directory([]);
    expect(groups.size).toBe(0);
  });

  it("files are sorted within groups", () => {
    const paths = ["docs/Z.md", "docs/A.md", "docs/M.md"];
    const groups = group_paths_by_directory(paths);
    expect(groups.get("docs")).toEqual(["docs/A.md", "docs/M.md", "docs/Z.md"]);
  });
});

describe("build_file_tree", () => {
  it("builds hierarchy from flat paths", () => {
    const paths = ["docs/A.md", "docs/B.md", "extensions/qmd/README.md", "README.md"];
    const tree = build_file_tree(paths);

    // dirs first, then files — sorted alphabetically
    expect(tree[0].is_dir).toBe(true);
    expect(tree[0].name).toBe("docs");
    expect(tree[0].file_count).toBe(2);
    expect(tree[0].children).toHaveLength(2);

    // extensions/qmd is collapsed into one node (single-child chain)
    expect(tree[1].is_dir).toBe(true);
    expect(tree[1].name).toBe("extensions/qmd");
    expect(tree[1].file_count).toBe(1);

    // root-level file
    expect(tree[2].is_dir).toBe(false);
    expect(tree[2].name).toBe("README.md");
  });

  it("collapses single-child directory chains", () => {
    const paths = ["a/b/c/file.md"];
    const tree = build_file_tree(paths);

    expect(tree).toHaveLength(1);
    expect(tree[0].name).toBe("a/b/c");
    expect(tree[0].is_dir).toBe(true);
    expect(tree[0].children).toHaveLength(1);
    expect(tree[0].children[0].name).toBe("file.md");
  });

  it("does not collapse when directory has multiple children", () => {
    const paths = ["a/b/file1.md", "a/c/file2.md"];
    const tree = build_file_tree(paths);

    expect(tree).toHaveLength(1);
    expect(tree[0].name).toBe("a");
    expect(tree[0].children).toHaveLength(2);
    expect(tree[0].children[0].name).toBe("b");
    expect(tree[0].children[1].name).toBe("c");
  });

  it("empty paths returns empty tree", () => {
    expect(build_file_tree([])).toEqual([]);
  });

  it("sorts dirs before files", () => {
    const paths = ["z-file.md", "a-dir/nested.md"];
    const tree = build_file_tree(paths);

    expect(tree[0].is_dir).toBe(true);
    expect(tree[0].name).toBe("a-dir");
    expect(tree[1].is_dir).toBe(false);
    expect(tree[1].name).toBe("z-file.md");
  });

  it("tags nodes with indexed state from provided set", () => {
    const paths = ["docs/A.md", "docs/B.md", "README.md"];
    const indexed = new Set(["docs/A.md", "README.md"]);
    const tree = build_file_tree(paths, indexed);

    // docs dir — some indexed
    expect(tree[0].is_dir).toBe(true);
    expect(tree[0].dir_index_status).toBe("some");

    // docs/A.md — indexed
    expect(tree[0].children[0].indexed).toBe(true);
    // docs/B.md — not indexed
    expect(tree[0].children[1].indexed).toBe(false);

    // README.md — indexed
    expect(tree[1].indexed).toBe(true);
  });

  it("dir_index_status is 'all' when all files indexed", () => {
    const paths = ["docs/A.md", "docs/B.md"];
    const indexed = new Set(["docs/A.md", "docs/B.md"]);
    const tree = build_file_tree(paths, indexed);

    expect(tree[0].dir_index_status).toBe("all");
  });

  it("dir_index_status is 'none' when no files indexed", () => {
    const paths = ["docs/A.md", "docs/B.md"];
    const tree = build_file_tree(paths, new Set());

    expect(tree[0].dir_index_status).toBe("none");
  });
});

describe("flatten_tree", () => {
  it("flattens fully expanded tree", () => {
    const paths = ["docs/A.md", "docs/B.md", "README.md"];
    const tree = build_file_tree(paths);
    const flat = flatten_tree(tree, new Set());

    // docs dir + 2 files + README
    expect(flat).toHaveLength(4);
    expect(flat[0].node.name).toBe("docs");
    expect(flat[0].depth).toBe(0);
    expect(flat[1].node.name).toBe("A.md");
    expect(flat[1].depth).toBe(1);
    expect(flat[3].node.name).toBe("README.md");
    expect(flat[3].depth).toBe(0);
  });

  it("respects collapsed directories", () => {
    const paths = ["docs/A.md", "docs/B.md", "README.md"];
    const tree = build_file_tree(paths);
    const collapsed = new Set(["docs"]);
    const flat = flatten_tree(tree, collapsed);

    // docs dir (collapsed) + README
    expect(flat).toHaveLength(2);
    expect(flat[0].node.name).toBe("docs");
    expect(flat[1].node.name).toBe("README.md");
  });
});

describe("wrap_text", () => {
  it("short text returns single line", () => {
    expect(wrap_text("hello", 80)).toEqual(["hello"]);
  });

  it("long text wraps at word boundary", () => {
    const text = "The local marker uses legacy collection key 'agents'. v1 expects 'p_abc123'.";
    const lines = wrap_text(text, 40);
    expect(lines.length).toBeGreaterThan(1);
    for (const line of lines) {
      expect(line.length).toBeLessThanOrEqual(40);
    }
  });

  it("respects indent", () => {
    const lines = wrap_text("a b c d e f g h i j k l m n o", 10, "  ");
    for (const line of lines) {
      expect(line.startsWith("  ")).toBe(true);
    }
  });

  it("handles text with no spaces", () => {
    const lines = wrap_text("abcdefghij", 5);
    expect(lines).toHaveLength(2);
    expect(lines[0]).toBe("abcde");
    expect(lines[1]).toBe("fghij");
  });
});
