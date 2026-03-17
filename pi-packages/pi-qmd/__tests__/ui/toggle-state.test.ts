import { describe, expect, it } from "vitest";
import { build_file_tree } from "../../ui/data.js";
import { ToggleState } from "../../ui/toggle-state.js";

describe("ToggleState", () => {
  describe("is_effectively_indexed", () => {
    it("returns true for originally indexed files", () => {
      const ts = new ToggleState(["a.md", "b.md"]);
      expect(ts.is_effectively_indexed("a.md")).toBe(true);
      expect(ts.is_effectively_indexed("b.md")).toBe(true);
    });

    it("returns false for non-indexed files", () => {
      const ts = new ToggleState(["a.md"]);
      expect(ts.is_effectively_indexed("b.md")).toBe(false);
    });

    it("returns true for pending adds", () => {
      const ts = new ToggleState([]);
      ts.set_file_state("new.md", true);
      expect(ts.is_effectively_indexed("new.md")).toBe(true);
    });

    it("returns false for pending removes", () => {
      const ts = new ToggleState(["old.md"]);
      ts.set_file_state("old.md", false);
      expect(ts.is_effectively_indexed("old.md")).toBe(false);
    });
  });

  describe("set_file_state", () => {
    it("adds to pending_adds when marking non-indexed as indexed", () => {
      const ts = new ToggleState([]);
      ts.set_file_state("new.md", true);
      expect(ts.pending_adds.has("new.md")).toBe(true);
      expect(ts.pending_removes.has("new.md")).toBe(false);
    });

    it("adds to pending_removes when marking indexed as not-indexed", () => {
      const ts = new ToggleState(["old.md"]);
      ts.set_file_state("old.md", false);
      expect(ts.pending_removes.has("old.md")).toBe(true);
      expect(ts.pending_adds.has("old.md")).toBe(false);
    });

    it("clears pending state when setting back to original", () => {
      const ts = new ToggleState(["a.md"]);
      ts.set_file_state("a.md", false); // pending remove
      expect(ts.pending_removes.has("a.md")).toBe(true);

      ts.set_file_state("a.md", true); // back to original
      expect(ts.pending_removes.has("a.md")).toBe(false);
      expect(ts.pending_adds.has("a.md")).toBe(false);
    });

    it("clears pending add when setting non-indexed back to not-indexed", () => {
      const ts = new ToggleState([]);
      ts.set_file_state("new.md", true); // pending add
      expect(ts.pending_adds.has("new.md")).toBe(true);

      ts.set_file_state("new.md", false); // back to original
      expect(ts.pending_adds.has("new.md")).toBe(false);
      expect(ts.pending_removes.has("new.md")).toBe(false);
    });
  });

  describe("toggle_file", () => {
    it("toggles indexed file to pending remove", () => {
      const ts = new ToggleState(["a.md"]);
      ts.toggle_file("a.md");
      expect(ts.is_effectively_indexed("a.md")).toBe(false);
      expect(ts.pending_removes.has("a.md")).toBe(true);
    });

    it("toggles non-indexed file to pending add", () => {
      const ts = new ToggleState([]);
      ts.toggle_file("a.md");
      expect(ts.is_effectively_indexed("a.md")).toBe(true);
      expect(ts.pending_adds.has("a.md")).toBe(true);
    });

    it("double toggle returns to original state", () => {
      const ts = new ToggleState(["a.md"]);
      ts.toggle_file("a.md"); // remove
      ts.toggle_file("a.md"); // back
      expect(ts.is_effectively_indexed("a.md")).toBe(true);
      expect(ts.has_pending()).toBe(false);
    });
  });

  describe("toggle_dir", () => {
    it("removes all when any descendant is indexed", () => {
      const paths = ["docs/a.md", "docs/b.md", "docs/c.md"];
      const indexed = new Set(["docs/a.md"]); // one indexed
      const tree = build_file_tree(paths, indexed);
      const ts = new ToggleState(["docs/a.md"]);

      ts.toggle_dir(tree[0]); // docs dir — has one indexed, so remove all
      expect(ts.is_effectively_indexed("docs/a.md")).toBe(false);
      expect(ts.is_effectively_indexed("docs/b.md")).toBe(false);
      expect(ts.is_effectively_indexed("docs/c.md")).toBe(false);
      expect(ts.pending_removes.has("docs/a.md")).toBe(true);
    });

    it("adds all when none are indexed", () => {
      const paths = ["docs/a.md", "docs/b.md"];
      const tree = build_file_tree(paths, new Set());
      const ts = new ToggleState([]);

      ts.toggle_dir(tree[0]); // docs dir — none indexed, so add all
      expect(ts.is_effectively_indexed("docs/a.md")).toBe(true);
      expect(ts.is_effectively_indexed("docs/b.md")).toBe(true);
      expect(ts.pending_adds.has("docs/a.md")).toBe(true);
      expect(ts.pending_adds.has("docs/b.md")).toBe(true);
    });

    it("double toggle on dir returns to original", () => {
      const paths = ["docs/a.md", "docs/b.md"];
      const tree = build_file_tree(paths, new Set(["docs/a.md", "docs/b.md"]));
      const ts = new ToggleState(["docs/a.md", "docs/b.md"]);

      ts.toggle_dir(tree[0]); // remove all
      expect(ts.pending_removes.size).toBe(2);

      ts.toggle_dir(tree[0]); // add all back
      expect(ts.has_pending()).toBe(false);
    });
  });

  describe("toggle_node", () => {
    it("dispatches to toggle_file for file nodes", () => {
      const paths = ["a.md"];
      const tree = build_file_tree(paths, new Set());
      const ts = new ToggleState([]);

      ts.toggle_node(tree[0]); // file node
      expect(ts.pending_adds.has("a.md")).toBe(true);
    });

    it("dispatches to toggle_dir for dir nodes", () => {
      const paths = ["docs/a.md", "docs/b.md"];
      const tree = build_file_tree(paths, new Set());
      const ts = new ToggleState([]);

      ts.toggle_node(tree[0]); // dir node
      expect(ts.pending_adds.has("docs/a.md")).toBe(true);
      expect(ts.pending_adds.has("docs/b.md")).toBe(true);
    });
  });

  describe("has_pending / pending_count / clear", () => {
    it("reports no pending initially", () => {
      const ts = new ToggleState(["a.md"]);
      expect(ts.has_pending()).toBe(false);
      expect(ts.pending_count()).toBe(0);
    });

    it("reports pending after toggle", () => {
      const ts = new ToggleState(["a.md"]);
      ts.toggle_file("a.md");
      expect(ts.has_pending()).toBe(true);
      expect(ts.pending_count()).toBe(1);
    });

    it("clear resets all pending", () => {
      const ts = new ToggleState(["a.md"]);
      ts.toggle_file("a.md");
      ts.set_file_state("b.md", true);
      expect(ts.pending_count()).toBe(2);

      ts.clear();
      expect(ts.has_pending()).toBe(false);
      expect(ts.pending_count()).toBe(0);
    });
  });
});
