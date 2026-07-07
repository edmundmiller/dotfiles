import { afterEach, describe, expect, it, vi } from "vitest";

import { runFeature } from "../src/run-feature";

interface CapturedRequest {
  url: string;
  method: string;
  body?: unknown;
}

function installFetch(): CapturedRequest[] {
  const captured: CapturedRequest[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      const method = init?.method ?? "GET";
      const body = init?.body ? JSON.parse(String(init.body)) : undefined;
      captured.push({ url, method, body });
      return new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    })
  );
  return captured;
}

describe("runFeature", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.useRealTimers();
  });

  it("posts one request and returns the created id", async () => {
    const captured = installFetch();

    const result = await runFeature({ name: "demo" });

    expect(result).toEqual({ id: "demo" });
    expect(captured).toEqual([
      {
        url: "https://example.test/features",
        method: "POST",
        body: { name: "demo" },
      },
    ]);
  });
});
