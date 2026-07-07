---
name: vitest
description: Use when writing Vitest tests, fake timers, vi mocks, or vitest runs.
---

# Vitest

Vitest work should stay **behavior-first**: one observable contract, one red test, one small implementation step, one targeted verification command.

## When to Use

- Writing or changing `*.test.ts`, `*.test.tsx`, or `*.spec.ts` files that use Vitest.
- Testing TypeScript/JavaScript behavior with `describe`, `it`, `expect`, `vi`, fake timers, globals, or module mocks.
- Choosing the smallest `vitest run` command for a red/green loop.

## Loop

1. **Find the seam.** Read the public function, CLI, hook, worker, or extension entrypoint under test plus one nearby test file. Stop when the next assertion can be written against a public effect.

2. **Write one red test.** Name the behavior, not the implementation. For bug fixes, reproduce the reported failure first and keep the test commit green with a strict expected-failure mechanism only when the repo already uses one.

3. **Use deterministic doubles.** Stub external edges: `fetch`, time, filesystem temp dirs, process env, network clients, or agent/runtime APIs. Avoid mocking the unit's private helpers.

4. **Assert the contract.** Prefer exact returned values, thrown errors, emitted requests, persisted files, status/UI changes, or stable rendered text. Do not assert call counts unless the count is the behavior.

5. **Run the narrowest command.** Use the package's existing script when present, otherwise run `vitest run <test-file>`. Completion criterion: the new/changed test fails before the fix for the expected reason and passes after the fix.

## House style

- Keep tests close to the feature: `test/**/*.test.ts`, `__tests__/domain/*.test.ts`, or the repo's existing convention.
- Put one-off helpers in the test file; move helpers only after real duplication appears.
- Use `vi.useFakeTimers`/`vi.setSystemTime` for time-sensitive behavior and restore in `afterEach`.
- Use `vi.stubGlobal` for browser/runtime APIs and `vi.unstubAllGlobals()` in cleanup.
- Prefer small in-memory fakes over broad `vi.fn()` webs. Store captured requests/events so assertions read like the contract.
- Use module mocks only for external collaborators; import the subject after `vi.mock` declarations.
- Keep TypeScript strict. If a test double intentionally implements only part of an API, use one local `@ts-expect-error` explaining that boundary.
- Avoid snapshots for ordinary objects. Use explicit expectations unless the artifact is large, stable, and reviewed as an artifact.

## Patterns

### Captured fetch fake

```ts
interface Captured {
  url: string;
  method: string;
  body?: unknown;
}

function installFetch(): Captured[] {
  const captured: Captured[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      const method = init?.method ?? "GET";
      captured.push({ url, method, body: init?.body && JSON.parse(String(init.body)) });
      return new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    })
  );
  return captured;
}
```

### Runtime fake

```ts
function createMockRuntime() {
  const handlers = new Map<string, Array<(event: unknown, ctx: unknown) => Promise<unknown>>>();
  return {
    on(name: string, handler: (event: unknown, ctx: unknown) => Promise<unknown>) {
      handlers.set(name, [...(handlers.get(name) ?? []), handler]);
    },
    async trigger(name: string, event: unknown, ctx: unknown) {
      let result: unknown;
      for (const handler of handlers.get(name) ?? []) result = await handler(event, ctx);
      return result;
    },
  };
}
```

## Commands

- Package script: `npm test -- <file>`, `pnpm test <file>`, or `bun test <file>` only if the repo already uses it.
- Direct Vitest: `vitest run path/to/file.test.ts`.
- Watch mode is for humans; agents should use non-watch `run`.

## Additional Resources

- `references/checklist.md` — seam, doubles, assertions, and command checklist.
- `references/vitest-evals.md` — Vitest Evals + Pi harness reference for skill evals.
- `templates/behavior.test.ts` — copyable behavior-test skeleton with captured `fetch`.
- `evals/skill.eval.ts`, `evals/README.md`, and `evals/scenarios.md` — Vitest Evals + Pi harness template, setup notes, and prompts.
- Optional script: `node scripts/run-targeted-vitest.mjs path/to/file.test.ts`.
