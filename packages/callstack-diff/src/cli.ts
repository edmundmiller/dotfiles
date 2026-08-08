#!/usr/bin/env bun
// callstack-diff (csd): render or diff static call-stack trees for JS/TS.
// Built on Effect v4: the command surface uses effect/unstable/cli and the
// program runs on the Bun platform runtime.
import { Console, Effect } from "effect";
import { Argument, Command, Flag } from "effect/unstable/cli";
import { BunRuntime, BunServices } from "@effect/platform-bun";
import { resolve } from "node:path";
import { analyze } from "./analyze.ts";
import { diffTrees } from "./diff.ts";
import { render, toRenderNode } from "./render.ts";
import type { BuildOptions } from "./tree.ts";
import { materializeRef, repoRoot } from "./git.ts";
import { describe, type CsdError } from "./errors.ts";

const VERSION = "0.1.0";

// Shared params ------------------------------------------------------------

const entry = Argument.string("entry").pipe(
  Argument.withDescription("Entry: name, Class.method, or file.ts#name")
);
const paths = Argument.string("paths").pipe(
  Argument.withDescription("Files or globs to scan (default: all JS/TS under --root)"),
  Argument.variadic
);
const root = Flag.string("root").pipe(
  Flag.withDefault("."),
  Flag.withDescription("Analysis root directory")
);
const depth = Flag.integer("depth").pipe(
  Flag.withDefault(6),
  Flag.withDescription("Max recursion depth")
);
const noBranches = Flag.boolean("no-branches").pipe(
  Flag.withDescription("Do not group if/else/switch into branch nodes")
);
const showArgs = Flag.boolean("args").pipe(
  Flag.withDescription("Include raw call arguments in labels")
);
const theme = Flag.choice("theme", ["default", "libretto", "none"] as const).pipe(
  Flag.withDefault("default"),
  Flag.withDescription("Color theme: default | libretto | none")
);
const from = Flag.string("from").pipe(
  Flag.withDefault("HEAD"),
  Flag.withDescription("Base git ref")
);
const to = Flag.string("to").pipe(
  Flag.withDefault(""),
  Flag.withDescription("Target git ref (default: working tree)")
);

interface Shared {
  readonly depth: number;
  readonly noBranches: boolean;
  readonly showArgs: boolean;
}

const buildOptions = (c: Shared): BuildOptions => ({
  maxDepth: c.depth,
  groupBranches: !c.noBranches,
  showArgs: c.showArgs,
});

// Report domain errors cleanly and exit non-zero instead of dumping a cause.
const report = <A, R>(program: Effect.Effect<A, CsdError, R>): Effect.Effect<void, never, R> =>
  program.pipe(
    Effect.asVoid,
    Effect.catch((error) =>
      Console.error(`csd: ${describe(error)}`).pipe(
        Effect.andThen(Effect.sync(() => void (process.exitCode = 1)))
      )
    )
  );

// Commands -----------------------------------------------------------------

const renderCommand = Command.make(
  "csd",
  { entry, paths, root, depth, noBranches, showArgs, theme },
  Effect.fn("callstack-diff.render")(function* (c) {
    yield* report(
      Effect.gen(function* () {
        const tree = yield* analyze({
          root: resolve(c.root),
          paths: c.paths,
          entry: c.entry,
          options: buildOptions(c),
        });
        yield* Console.log(render(toRenderNode(tree), { theme: c.theme, diff: false }));
      })
    );
  })
).pipe(Command.withDescription("Render a static call-stack tree for JS/TS, powered by Oxc"));

const diffCommand = Command.make(
  "diff",
  { entry, paths, root, depth, noBranches, showArgs, theme, from, to },
  Effect.fn("callstack-diff.diff")(function* (c) {
    yield* report(
      Effect.scoped(
        Effect.gen(function* () {
          const repo = yield* repoRoot(resolve(c.root));
          const options = buildOptions(c);
          const beforeRoot = yield* materializeRef(c.from, repo);
          const before = yield* analyze({
            root: beforeRoot,
            paths: c.paths,
            entry: c.entry,
            options,
          });
          const afterRoot = c.to === "" ? resolve(c.root) : yield* materializeRef(c.to, repo);
          const after = yield* analyze({
            root: afterRoot,
            paths: c.paths,
            entry: c.entry,
            options,
          });
          yield* Console.log(render(diffTrees(before, after), { theme: c.theme, diff: true }));
        })
      )
    );
  })
).pipe(Command.withDescription("Diff the call-stack tree between two git revisions"));

const command = renderCommand.pipe(Command.withSubcommands([diffCommand]));

const program = command.pipe(Command.run({ version: VERSION }));

BunRuntime.runMain(program.pipe(Effect.provide(BunServices.layer)));
