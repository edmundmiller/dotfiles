import { describe, expect, it } from "vitest";
import { handelize_path } from "../../core/qmd-store.js";

describe("handelize_path", () => {
  it("lowercases paths", () => {
    expect(handelize_path("docs/ARCHITECTURE.md")).toBe("docs/architecture.md");
  });

  it("strips leading dots from directory segments", () => {
    expect(handelize_path(".pi/tracks/summary.md")).toBe("pi/tracks/summary.md");
  });

  it("replaces non-alphanumeric chars with hyphens", () => {
    expect(handelize_path("docs/my file (1).md")).toBe("docs/my-file-1.md");
  });

  it("preserves file extension", () => {
    expect(handelize_path("README.md")).toBe("readme.md");
    expect(handelize_path("notes.mdx")).toBe("notes.mdx");
  });

  it("collapses multiple special chars into single hyphen", () => {
    expect(handelize_path("docs/a---b___c.md")).toBe("docs/a-b-c.md");
  });

  it("strips leading/trailing hyphens from segments", () => {
    expect(handelize_path("-docs-/--file--.md")).toBe("docs/file.md");
  });

  it("handles deeply nested paths", () => {
    expect(handelize_path(".pi/tracks/agent-memory/workstreams/notes.md")).toBe(
      "pi/tracks/agent-memory/workstreams/notes.md"
    );
  });

  it("filters out empty segments", () => {
    expect(handelize_path("docs//nested/file.md")).toBe("docs/nested/file.md");
  });
});
