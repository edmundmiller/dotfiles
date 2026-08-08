// Tagged domain errors for the csd pipeline. Keeping them in the Effect error
// channel lets the CLI report a clean message and exit non-zero without
// throwing.
import { Data } from "effect";

export class NoSourceFiles extends Data.TaggedError("NoSourceFiles")<{
  readonly root: string;
}> {}

export class EntryNotFound extends Data.TaggedError("EntryNotFound")<{
  readonly entry: string;
}> {}

export class GitError extends Data.TaggedError("GitError")<{
  readonly message: string;
}> {}

export type CsdError = NoSourceFiles | EntryNotFound | GitError;

export function describe(error: CsdError): string {
  switch (error._tag) {
    case "NoSourceFiles":
      return `no JS/TS source files under ${error.root}`;
    case "EntryNotFound":
      return `could not resolve entry "${error.entry}"`;
    case "GitError":
      return error.message;
  }
}
