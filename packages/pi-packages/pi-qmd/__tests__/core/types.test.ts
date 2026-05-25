import { describe, expect, it } from "vitest";
import { qmd_init_params_schema, qmd_repo_marker_schema } from "../../core/types.js";

describe("qmd_repo_marker_schema", () => {
  it("accepts a valid marker", () => {
    const result = qmd_repo_marker_schema.parse({
      schema_version: 1,
      repo_root: "/tmp/repo",
      collection_key: "p_L3RtcC9yZXBv",
      last_indexed_at: "2026-03-13T12:00:00.000Z",
      last_indexed_commit: "abc123",
      created_at: "2026-03-13T11:00:00.000Z",
    });

    expect(result.collection_key).toBe("p_L3RtcC9yZXBv");
  });

  it("rejects the wrong schema version", () => {
    const result = qmd_repo_marker_schema.safeParse({
      schema_version: 2,
      repo_root: "/tmp/repo",
      collection_key: "p_x",
      last_indexed_at: "now",
      last_indexed_commit: "abc123",
      created_at: "now",
    });

    expect(result.success).toBe(false);
  });
});

describe("qmd_init_params_schema", () => {
  it("accepts valid onboarding input", () => {
    const result = qmd_init_params_schema.parse({
      root: "/tmp/repo",
      glob_pattern: "**/*.md",
      paths: [{ path: "docs", annotation: "Documentation" }],
    });

    expect(result.paths).toHaveLength(1);
  });

  it("requires a non-empty root", () => {
    const result = qmd_init_params_schema.safeParse({
      root: "",
      paths: [],
    });

    expect(result.success).toBe(false);
  });
});
