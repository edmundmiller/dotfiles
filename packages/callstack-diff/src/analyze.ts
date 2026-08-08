// The analysis pipeline as an Effect: discover files, index declarations,
// resolve the entry, and build the call-stack tree. Pure parsing/tree logic
// lives in project.ts and tree.ts; this wraps it with typed failures.
import { Effect } from "effect";
import { discover } from "./discover.ts";
import { buildIndex, resolveEntry } from "./project.ts";
import { buildTree, type BuildOptions, type CallNode } from "./tree.ts";
import { EntryNotFound, NoSourceFiles } from "./errors.ts";

export interface AnalyzeParams {
  readonly root: string;
  readonly paths: readonly string[];
  readonly entry: string;
  readonly options: BuildOptions;
}

export function analyze(
  params: AnalyzeParams
): Effect.Effect<CallNode, NoSourceFiles | EntryNotFound> {
  return Effect.gen(function* () {
    const files = yield* Effect.sync(() => discover(params.root, params.paths));
    if (files.length === 0) return yield* Effect.fail(new NoSourceFiles({ root: params.root }));

    const index = yield* Effect.sync(() => buildIndex(files));
    const entry = resolveEntry(index, params.entry);
    if (!entry) return yield* Effect.fail(new EntryNotFound({ entry: params.entry }));

    return buildTree(index, entry, params.options);
  });
}
