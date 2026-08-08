// Materialize a git ref's tree into a temporary directory so the analyzer can
// index a past revision the same way it indexes the working tree. Git and tar
// run through Effect's platform process service; failures stay on the typed
// error channel as GitError.
import { Effect, FileSystem, Stream } from "effect";
import { ChildProcess, ChildProcessSpawner } from "effect/unstable/process";
import { join } from "node:path";
import { GitError } from "./errors.ts";

interface CommandResult {
  readonly stdout: string;
  readonly stderr: string;
  readonly exitCode: number;
}

const runCommand = Effect.fn("callstack-diff.runCommand")(function* (
  command: ChildProcess.Command,
  context: string
) {
  return yield* Effect.scoped(
    Effect.gen(function* () {
      const spawner = yield* ChildProcessSpawner.ChildProcessSpawner;
      const handle = yield* spawner.spawn(command);
      const [stdout, stderr, exitCode] = yield* Effect.all(
        [
          Stream.decodeText(handle.stdout).pipe(Stream.mkString),
          Stream.decodeText(handle.stderr).pipe(Stream.mkString),
          handle.exitCode,
        ],
        { concurrency: "unbounded" }
      );
      return { stdout, stderr, exitCode: Number(exitCode) } satisfies CommandResult;
    })
  ).pipe(Effect.mapError((cause) => new GitError({ message: `${context}: ${String(cause)}` })));
});

export const repoRoot = Effect.fn("callstack-diff.repoRoot")(function* (cwd: string) {
  const result = yield* runCommand(
    ChildProcess.make("git", ["rev-parse", "--show-toplevel"], { cwd }),
    `failed to inspect git repository at ${cwd}`
  );
  const root = result.stdout.trim();
  if (result.exitCode !== 0 || root === "") {
    const detail = result.stderr.trim() || "not a git repository";
    return yield* new GitError({ message: `not a git repository: ${cwd} (${detail})` });
  }
  return root;
});

// Extract `ref` into a fresh temp dir via `git archive` and return its path.
export const materializeRef = Effect.fn("callstack-diff.materializeRef")(function* (
  ref: string,
  root: string
) {
  const fileSystem = yield* FileSystem.FileSystem;
  const dir = yield* fileSystem
    .makeTempDirectoryScoped({ prefix: "csd-" })
    .pipe(
      Effect.mapError(
        (cause) =>
          new GitError({ message: `failed to create temporary directory: ${String(cause)}` })
      )
    );
  const archivePath = join(dir, "archive.tar");
  const archive = yield* runCommand(
    ChildProcess.make("git", ["archive", "--format=tar", `--output=${archivePath}`, ref], {
      cwd: root,
    }),
    `git archive ${ref} failed`
  );
  if (archive.exitCode !== 0) {
    return yield* new GitError({
      message: `git archive ${ref} failed: ${archive.stderr.trim() || `exit ${archive.exitCode}`}`,
    });
  }
  const extract = yield* runCommand(
    ChildProcess.make("tar", ["-xf", archivePath, "-C", dir]),
    `tar extract failed for ${ref}`
  );
  if (extract.exitCode !== 0) {
    return yield* new GitError({
      message: `tar extract failed for ${ref}: ${extract.stderr.trim() || `exit ${extract.exitCode}`}`,
    });
  }
  return dir;
});
