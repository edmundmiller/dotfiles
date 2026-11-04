import { afterEach, expect, mock, spyOn, test } from "bun:test";
import type { ChangesetTransform, ExtensionChangeset } from "hunkdiff/extension";
import jevPriority from "./jev-priority";

const originalEnv = { ...process.env };
afterEach(() => {
  mock.restore();
  for (const name of ["HUNK_JEV_PRIORITY", "TYPESAFE_API_KEY", "HUNK_JEV_MODEL"]) {
    if (originalEnv[name] === undefined) delete process.env[name];
    else process.env[name] = originalEnv[name];
  }
});

function setup() {
  process.env.HUNK_JEV_PRIORITY = "1";
  process.env.TYPESAFE_API_KEY = "test-only";
  delete process.env.HUNK_JEV_MODEL;
  let transform!: ChangesetTransform;
  jevPriority({ transformChangeset: (fn) => (transform = fn) });
  const notify = mock(() => {});
  const changeset: ExtensionChangeset = {
    id: "review",
    title: "Change authentication",
    sourceLabel: "diff",
    files: ["README.md", "auth.ts", "auth.test.ts", "notes.md"].map((path, index) => ({
      id: `original:${index}:${path}`,
      path,
      patch: `-before ${index}\n+after ${index}`,
      stats: { additions: 1, deletions: 1 },
      metadata: {},
      agent: null,
    })),
  };
  const run = (input = changeset) => transform(input, { cwd: "/unused", notify });
  return { changeset, run, notify };
}

function response(scores = [0.2, 2.9, 1.6, 0.2]) {
  return Response.json({
    answers: Object.fromEntries(scores.map((score, i) => [`file_${i}`, { type: "score", score }])),
  });
}

function mockFetch(reply: () => Response | Promise<Response> = () => response()) {
  return spyOn(globalThis, "fetch").mockImplementation(
    Object.assign(async () => reply(), { preconnect: fetch.preconnect })
  );
}

test("orders by Jev score, preserves objects and ties, and caches only unchanged evidence", async () => {
  const { changeset, run } = setup();
  const fetcher = mockFetch();
  const ranked = await run();
  expect(ranked.files.map((file) => file.path)).toEqual([
    "auth.ts",
    "auth.test.ts",
    "README.md",
    "notes.md",
  ]);
  expect(ranked.files[0]).toBe(changeset.files[1]);
  expect(changeset.files[0]!.path).toBe("README.md");
  expect(ranked.id).toBe(changeset.id);
  await run();
  expect(fetcher).toHaveBeenCalledTimes(1);
  const [url, options] = fetcher.mock.calls[0]!;
  expect(url).toBe("https://api.typesafe.ai/v1/systemone");
  expect(options?.headers).toEqual({
    Authorization: "Bearer test-only",
    "Content-Type": "application/json",
  });
  const request = JSON.parse(String(options?.body));
  expect(request.model).toBe("jev-latest");
  expect(request.state.files[1].patch).toBe(changeset.files[1]!.patch);
  expect(request.questions.file_1.instructions).toContain("`files[1]`");
  changeset.files[1]!.patch += "\n+changed";
  await run();
  expect(fetcher).toHaveBeenCalledTimes(2);
  process.env.HUNK_JEV_MODEL = "jev-1.13";
  await run();
  expect(fetcher).toHaveBeenCalledTimes(3);
});

test("requires explicit opt-in and a key, and skips a single-file review", async () => {
  const { changeset, run, notify } = setup();
  const fetcher = mockFetch();
  delete process.env.HUNK_JEV_PRIORITY;
  expect(await run()).toBe(changeset);
  expect(notify).not.toHaveBeenCalled();
  process.env.HUNK_JEV_PRIORITY = "1";
  delete process.env.TYPESAFE_API_KEY;
  expect(await run()).toBe(changeset);
  expect(notify).toHaveBeenCalledTimes(1);
  process.env.TYPESAFE_API_KEY = "test-only";
  const single = { ...changeset, files: changeset.files.slice(0, 1) };
  expect(await run(single)).toBe(single);
  expect(fetcher).not.toHaveBeenCalled();
});

test.each([
  () => new Response("private provider error", { status: 429 }),
  () => new Response("not json"),
  () => Response.json(null),
  () => response([1]),
  () => response([1, 2, 3, 4]),
  () => response([1, 2, 3, -0.1]),
  () => Response.json({ answers: { file_0: { type: "choice", score: 2 } } }),
  () => {
    throw new DOMException("private timeout details", "TimeoutError");
  },
])("keeps the complete incoming order on provider failure", async (reply) => {
  const { changeset, run, notify } = setup();
  const fetcher = mockFetch(reply);
  expect(await run()).toBe(changeset);
  const refreshed = { ...changeset, title: "Refreshed review" };
  expect(await run(refreshed)).toBe(refreshed);
  expect(fetcher).toHaveBeenCalledTimes(1);
  expect(notify).toHaveBeenCalledTimes(1);
  expect(JSON.stringify(notify.mock.calls)).not.toContain("private");
  changeset.files[0]!.patch += "\n+new evidence";
  expect(await run()).toBe(changeset);
  expect(fetcher).toHaveBeenCalledTimes(2);
  process.env.HUNK_JEV_MODEL = "jev-1.13";
  await run();
  expect(fetcher).toHaveBeenCalledTimes(3);
  process.env.TYPESAFE_API_KEY += "-corrected";
  await run();
  expect(fetcher).toHaveBeenCalledTimes(4);
});

test("shares an in-flight attempt across unchanged refreshes", async () => {
  const { changeset, run } = setup();
  const pending = Promise.withResolvers<Response>();
  const fetcher = mockFetch(() => pending.promise);
  const first = run();
  const refreshed = { ...changeset, title: "Refreshed review" };
  const second = run(refreshed);
  const newer = {
    ...changeset,
    files: changeset.files.map((file) => ({ ...file, patch: file.patch + "\n+newer" })),
  };
  fetcher.mockResolvedValueOnce(response([3, 2, 1, 0]));
  const latest = await run(newer);
  expect(latest.files.map((file) => file.path)).toEqual([
    "README.md",
    "auth.ts",
    "auth.test.ts",
    "notes.md",
  ]);
  pending.resolve(response());
  const [a, b] = await Promise.all([first, second]);
  expect(a.files.map((file) => file.path)).toEqual([
    "auth.ts",
    "auth.test.ts",
    "README.md",
    "notes.md",
  ]);
  expect(b.files).toEqual(a.files);
  expect(b.title).toBe("Refreshed review");
  expect((await run(newer)).files).toEqual(latest.files);
  expect(fetcher).toHaveBeenCalledTimes(2);
});

test.each(["headers", "body"])(
  "abandons slow %s before commit navigation expires",
  async (phase) => {
    const { changeset, run } = setup();
    const server = Bun.serve({
      hostname: "127.0.0.1",
      port: 0,
      async fetch() {
        if (phase === "headers") {
          await Bun.sleep(4500);
          return response();
        }
        return new Response(
          new ReadableStream({
            async start(controller) {
              controller.enqueue(new TextEncoder().encode('{"answers":'));
              await Bun.sleep(4500);
              controller.close();
            },
          })
        );
      },
    });
    const realFetch = globalThis.fetch;
    const fetcher = spyOn(globalThis, "fetch").mockImplementation(
      Object.assign(
        (_url: Parameters<typeof fetch>[0], options?: RequestInit) =>
          realFetch(server.url, options),
        { preconnect: realFetch.preconnect }
      )
    );
    try {
      const started = performance.now();
      expect(await run()).toBe(changeset);
      expect(performance.now() - started).toBeLessThan(3500);
      expect(await run()).toBe(changeset);
      expect(fetcher).toHaveBeenCalledTimes(1);
    } finally {
      await server.stop(true);
    }
  },
  10000
);

test("bounds requests and explicitly marks sampled patches", async () => {
  const { changeset, run } = setup();
  changeset.files[0]!.patch = "HEAD" + "x".repeat(20000) + "TAIL";
  const fetcher = mockFetch();
  await run();
  const body = JSON.parse(String(fetcher.mock.calls[0]![1]?.body));
  expect(body.state.files[0].truncated).toBe(true);
  expect(body.state.files[0].patch).toStartWith("HEAD");
  expect(body.state.files[0].patch).toEndWith("TAIL");
  expect(body.state.files[0].patch.length).toBeLessThan(4100);
  const huge = { ...changeset, files: Array.from({ length: 65 }, () => changeset.files[0]!) };
  expect(await run(huge)).toBe(huge);
  changeset.files[0]!.path = "x".repeat(65000);
  expect(await run()).toBe(changeset);
  expect(fetcher).toHaveBeenCalledTimes(1);
});

test("retains duplicate-path occurrence order even when scores disagree", async () => {
  const { changeset, run } = setup();
  changeset.files[3]!.path = changeset.files[0]!.path;
  changeset.files[0]!.previousPath = "renamed.md";
  const fetcher = mockFetch(() => response([0.1, 2, 1, 3]));
  const ranked = await run();
  expect(ranked.files.map((file) => file.id)).toEqual([
    changeset.files[1]!.id,
    changeset.files[2]!.id,
    changeset.files[0]!.id,
    changeset.files[3]!.id,
  ]);
  changeset.files[0]!.patch += "\n+changed";
  fetcher.mockResolvedValueOnce(response([3, 2, 1, 0.1]));
  const reloaded = await run();
  expect(reloaded.files.map((file) => file.id)).toEqual([
    changeset.files[0]!.id,
    changeset.files[3]!.id,
    changeset.files[1]!.id,
    changeset.files[2]!.id,
  ]);
});
