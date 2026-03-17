import { describe, expect, it, vi } from "vitest";

vi.mock("../../domain/repo-binding.js", () => ({
  detect_repo_binding: async () => ({
    status: "indexed",
    repo_root: "/tmp/repo",
    collection_key: "p_demo",
    marker: {
      schema_version: 1,
      repo_root: "/tmp/repo",
      collection_key: "p_demo",
      last_indexed_at: "2026-03-13T12:00:00.000Z",
      last_indexed_commit: "abc123",
      created_at: "2026-03-13T11:00:00.000Z",
    },
    source: "marker",
  }),
}));

vi.mock("../../domain/freshness.js", () => ({
  check_freshness: async () => ({ status: "fresh" }),
}));

vi.mock("../../core/qmd-store.js", () => ({
  close_store: async () => {},
}));

import { type QmdExtensionState, register_runtime } from "../../extension/runtime.js";

function create_mock_pi() {
  const handlers = new Map<string, Array<(event: any, ctx: any) => Promise<any>>>();
  return {
    on(event_name: string, handler: (event: any, ctx: any) => Promise<any>) {
      const list = handlers.get(event_name) ?? [];
      list.push(handler);
      handlers.set(event_name, list);
    },
    async trigger(event_name: string, event: any, ctx: any) {
      let result: any;
      for (const handler of handlers.get(event_name) ?? []) {
        result = await handler(event, ctx);
      }
      return result;
    },
  };
}

function create_mock_ctx() {
  const statuses = new Map<string, string | undefined>();
  return {
    statuses,
    ui: {
      setStatus(key: string, value: string | undefined) {
        statuses.set(key, value);
      },
    },
  };
}

describe("runtime hooks", () => {
  it("sets a quiet indexed footer and injects QMD guidance", async () => {
    const pi = create_mock_pi();
    const state: QmdExtensionState = {};
    // @ts-expect-error test double only implements the ExtensionAPI surface used here.
    register_runtime(pi, state);

    const ctx = create_mock_ctx();
    await pi.trigger("session_start", {}, ctx);
    expect(ctx.statuses.get("qmd")).toBe("qmd: indexed ✓");

    const result = await pi.trigger("before_agent_start", { systemPrompt: "base" }, ctx);
    expect(result.systemPrompt).toContain(
      "This repository is indexed by QMD (collection: `p_demo`)."
    );
    expect(result.systemPrompt).toContain("qmd query -c p_demo");
    expect(result.systemPrompt).toContain("**Use QMD before rg/grep when:**");
  });
});
