# Vitest Checklist

Use this when a Vitest task needs more than the core loop in `SKILL.md`.

## Seam

- Name the public behavior first: function result, thrown error, emitted request, runtime event, rendered text, or persisted file.
- Read one nearby test before choosing imports, helper placement, and package command.
- Mock only external edges: network, time, filesystem temp dirs, process env, runtime APIs, or module-level collaborators.

## Doubles

- Prefer captured in-memory fakes over deep `vi.fn()` chains.
- Restore global state in `afterEach` with `vi.unstubAllGlobals()` and `vi.useRealTimers()`.
- Put one-off fakes in the test file. Extract helpers only after duplication appears.

## Assertions

- Assert exact data at the boundary.
- Assert call counts only when the count is the contract.
- Use snapshots only for large stable artifacts that reviewers can inspect.

## Command

- Prefer the repo script when it already exists.
- Otherwise run `vitest run path/to/file.test.ts`.
- Never use watch mode from an agent session.
