import { createHash } from "node:crypto";
import { lstat, readFile, readlink } from "node:fs/promises";
import path from "node:path";

const CONTINUE_MESSAGE =
  "Completion gate not satisfied. Run completion_check; fix every reported failure, rerun it after the final change, and do not answer the user until it passes.";
const TOOL_DESCRIPTION =
  "Run required dotfiles completion checks after all requested work and final edits are complete. A pass is valid for the next stop attempt only.";

function hash(value) {
  return createHash("sha256").update(value).digest("hex");
}

function cancelled(signal, result) {
  return signal?.aborted || result?.killed || result?.code === null;
}

async function git(pi, root, args, signal, label) {
  if (signal?.aborted) throw new Error(`${label} timed out or was cancelled.`);
  const result = await pi.exec("git", ["-C", root, ...args], { signal });
  if (signal?.aborted) throw new Error(`${label} timed out or was cancelled.`);
  if (result.killed || result.code !== 0) {
    const detail = result.stderr?.trim();
    throw new Error(`${label} failed${detail ? `: ${detail}` : "."}`);
  }
  return result.stdout;
}

async function untrackedEntry(root, relative, signal) {
  if (signal?.aborted) throw new Error("Repository snapshot timed out or was cancelled.");
  const absolute = path.join(root, relative);
  const info = await lstat(absolute);
  let kind;
  let content;
  if (info.isFile()) {
    kind = "file";
    content = await readFile(absolute, { signal });
  } else if (info.isSymbolicLink()) {
    kind = "symlink";
    content = await readlink(absolute);
  } else {
    throw new Error(`Unsupported untracked file kind: ${relative}`);
  }
  if (signal?.aborted) throw new Error("Repository snapshot timed out or was cancelled.");
  return { path: relative, kind, hash: hash(content) };
}

export async function snapshot(pi, root, signal) {
  const head = (await git(pi, root, ["rev-parse", "HEAD"], signal, "git rev-parse HEAD")).trim();
  const status = await git(
    pi,
    root,
    ["status", "--porcelain=v1", "-z", "--untracked-files=all"],
    signal,
    "git status"
  );
  const diff = await git(pi, root, ["diff", "--binary", "HEAD", "--", "."], signal, "git diff");
  const others = await git(
    pi,
    root,
    ["ls-files", "--others", "--exclude-standard", "-z"],
    signal,
    "git ls-files"
  );
  const paths = others.split("\0").filter(Boolean).sort();
  const untracked = [];
  for (const relative of paths) untracked.push(await untrackedEntry(root, relative, signal));
  return hash(JSON.stringify({ head, status, diff, untracked }));
}

function toolResult(message, isError = false) {
  return {
    content: [{ type: "text", text: message }],
    ...(isError ? { isError: true } : {}),
  };
}

function checkFailure(result) {
  const diagnostics = [result.stderr?.trim(), result.stdout?.trim()].filter(Boolean).join("\n");
  return diagnostics || `Completion checks failed with exit code ${result.code}.`;
}

function executionError(error, signal) {
  const message = error instanceof Error ? error.message : String(error);
  if (
    signal?.aborted ||
    (error instanceof Error && ["AbortError", "TimeoutError"].includes(error.name)) ||
    /timed out|cancelled/i.test(message)
  ) {
    return "Completion checks were cancelled or timed out.";
  }
  return message;
}

export default function completionGate(pi) {
  let root;
  let verifiedSnapshot;

  const clearVerification = () => {
    verifiedSnapshot = undefined;
  };

  pi.registerTool({
    name: "completion_check",
    label: "Completion Check",
    description: TOOL_DESCRIPTION,
    parameters: pi.zod.object({}),
    defaultInactive: true,
    approval: "read",
    execute: async (_id, _params, signal) => {
      clearVerification();
      if (!root)
        return toolResult("Completion gate is inactive outside the dotfiles repository.", true);

      let before;
      try {
        before = await snapshot(pi, root, signal);
      } catch (error) {
        return toolResult(executionError(error, signal), true);
      }

      let result;
      try {
        result = await pi.exec("bash", ["scripts/completion-check"], {
          cwd: root,
          signal,
          timeout: 1_200_000,
        });
      } catch (error) {
        return toolResult(executionError(error, signal), true);
      }
      if (cancelled(signal, result))
        return toolResult("Completion checks were cancelled or timed out.", true);
      if (result.code !== 0) return toolResult(checkFailure(result), true);

      let after;
      try {
        after = await snapshot(pi, root, signal);
      } catch (error) {
        return toolResult(executionError(error, signal), true);
      }
      if (before !== after) {
        return toolResult(
          "Working tree changed while completion checks ran; rerun completion_check.",
          true
        );
      }

      verifiedSnapshot = after;
      return toolResult("Completion checks passed for the current repository snapshot.");
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    clearVerification();
    root = undefined;
    const previousActive = pi.getActiveTools();
    if (previousActive.includes("completion_check")) {
      pi.setActiveTools(previousActive.filter((name) => name !== "completion_check"));
    }
    let candidate;
    try {
      const result = await pi.exec("git", ["-C", ctx.cwd, "rev-parse", "--show-toplevel"], {});
      if (result.killed || result.code !== 0) return;
      candidate = result.stdout.trim();
      const markers = await pi.exec(
        "git",
        [
          "-C",
          candidate,
          "ls-files",
          "--error-unmatch",
          "--",
          ".codex/hooks.json",
          "scripts/codex-validate-stop",
        ],
        {}
      );
      if (markers.killed || markers.code !== 0) return;
    } catch {
      return;
    }
    root = candidate;
    const active = pi.getActiveTools();
    pi.setActiveTools([...active, "completion_check"]);
  });

  for (const event of ["session_switch", "session_branch", "session_tree"]) {
    pi.on(event, clearVerification);
  }

  pi.on("session_stop", async () => {
    if (!root) return undefined;
    const expected = verifiedSnapshot;
    clearVerification();
    if (expected) {
      try {
        const current = await snapshot(pi, root, AbortSignal.timeout(20_000));
        if (current === expected) return undefined;
      } catch (error) {
        const detail = error instanceof Error ? error.message : String(error);
        return {
          continue: true,
          additionalContext: `${CONTINUE_MESSAGE}\nSnapshot error: ${detail}`,
        };
      }
    }
    return { continue: true, additionalContext: CONTINUE_MESSAGE };
  });
}
