import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, isAbsolute, join } from "node:path";

const HUNK_TIMEOUT_MS = 30_000;

const textResult = (text: string, details: Record<string, unknown> = {}) => ({
  content: [{ type: "text" as const, text }],
  details,
});

const parseJson = (text: string): unknown => {
  const trimmed = text.trim();
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed);
  } catch {
    return trimmed;
  }
};

const stringify = (value: unknown): string =>
  typeof value === "string" ? value : JSON.stringify(value, null, 2);

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const findStringKey = (value: unknown, key: string): string | undefined => {
  if (Array.isArray(value)) {
    for (const item of value) {
      const found = findStringKey(item, key);
      if (found) return found;
    }
    return undefined;
  }
  if (!isRecord(value)) return undefined;
  for (const [candidate, item] of Object.entries(value)) {
    if (candidate === key && typeof item === "string" && item) return item;
    const found = findStringKey(item, key);
    if (found) return found;
  }
  return undefined;
};

const shellWord = (value: string): string =>
  /^[A-Za-z0-9_./:@%+=,-]+$/.test(value) ? value : `'${value.replace(/'/g, "'\\''")}'`;

export const buildHunkCommand = (args: string[]): string => {
  const rendered = args.map(shellWord).join(" ");
  return [
    "if command -v hunk >/dev/null 2>&1; then",
    `exec hunk ${rendered};`,
    "fi;",
    `exec bunx hunkdiff ${rendered}`,
  ].join(" ");
};

async function runCommand(
  pi: ExtensionAPI,
  command: string,
  args: string[],
  options: { cwd?: string; timeout?: number; stdin?: string } = {}
) {
  const execOptions = {
    cwd: options.cwd ?? process.cwd(),
    timeout: options.timeout ?? HUNK_TIMEOUT_MS,
    input: options.stdin,
  };
  const result = await pi.exec(command, args, {
    ...execOptions,
  });

  const stdout = result.stdout?.trim() ?? "";
  const stderr = result.stderr?.trim() ?? "";
  if (result.code !== 0) {
    throw new Error(
      [`${command} ${args.join(" ")} failed with exit code ${result.code}`, stdout, stderr]
        .filter(Boolean)
        .join("\n\n")
    );
  }
  return { stdout, stderr, code: result.code };
}

function repoArg(repo?: string): string {
  return repo || process.cwd();
}

async function gitPath(pi: ExtensionAPI, repo: string, path: string): Promise<string> {
  const result = await runCommand(pi, "git", ["rev-parse", "--git-path", path], { cwd: repo });
  return isAbsolute(result.stdout) ? result.stdout : join(repo, result.stdout);
}

async function writePiLastTurnMarker(
  pi: ExtensionAPI,
  repo: string,
  input: { range?: string; staged?: boolean; pathspecs?: string[] }
) {
  const markerPath = await gitPath(pi, repo, "hunk/last-pi-turn.json");
  await mkdir(dirname(markerPath), { recursive: true });
  await writeFile(
    markerPath,
    `${JSON.stringify(
      {
        version: 1,
        source: "pi-hunk",
        createdAt: new Date().toISOString(),
        kind: "vcs",
        range: input.range,
        staged: input.staged === true,
        pathspecs: input.pathspecs,
      },
      null,
      2
    )}\n`
  );
  return markerPath;
}

async function openHunkInHerdr(
  pi: ExtensionAPI,
  repo: string,
  placement: "pane" | "tab",
  hunkArgs: string[]
) {
  if (process.env.HERDR_ENV !== "1") {
    throw new Error("hunk_diff requires HERDR_ENV=1 in a Herdr-managed pane");
  }

  const herdr = process.env.HERDR_BIN_PATH || "herdr";
  const createArgs =
    placement === "tab"
      ? (() => {
          const workspaceId = process.env.HERDR_WORKSPACE_ID;
          if (!workspaceId)
            throw new Error("hunk_diff requires HERDR_WORKSPACE_ID for tab placement");
          return [
            "tab",
            "create",
            "--workspace",
            workspaceId,
            "--cwd",
            repo,
            "--label",
            "hunk",
            "--focus",
          ];
        })()
      : (() => {
          const paneId = process.env.HERDR_PANE_ID;
          if (!paneId) throw new Error("hunk_diff requires HERDR_PANE_ID for pane placement");
          return ["pane", "split", paneId, "--direction", "right", "--cwd", repo, "--focus"];
        })();

  const created = await runCommand(pi, herdr, createArgs, { cwd: repo, timeout: 10_000 });
  const targetPaneId = findStringKey(parseJson(created.stdout), "pane_id");
  if (!targetPaneId) throw new Error("could not find pane_id in Herdr create response");

  const command = buildHunkCommand(hunkArgs);
  await runCommand(pi, herdr, ["pane", "rename", targetPaneId, "hunk"], { cwd: repo });
  const result = await runCommand(pi, herdr, ["pane", "run", targetPaneId, command], {
    cwd: repo,
  });
  return { ...result, command, paneId: targetPaneId };
}

export default function hunkExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "hunk_diff",
    label: "Hunk Diff",
    description:
      "Open a Hunk diff review for working-tree or staged changes. Use this to start/refresh the visual human review surface.",
    parameters: Type.Object({
      repo: Type.Optional(
        Type.String({ description: "Repository path. Defaults to Pi's current working directory." })
      ),
      target: Type.Optional(
        Type.String({ description: "Optional diff target/ref, e.g. HEAD or main...HEAD." })
      ),
      staged: Type.Optional(
        Type.Boolean({ description: "Review staged changes instead of working tree changes." })
      ),
      watch: Type.Optional(Type.Boolean({ description: "Auto-reload as the diff changes." })),
      excludeUntracked: Type.Optional(Type.Boolean({ description: "Hide untracked files." })),
      pathspecs: Type.Optional(
        Type.Array(Type.String(), { description: "Optional git pathspecs to limit the review." })
      ),
      placement: Type.Optional(
        Type.Union([Type.Literal("pane"), Type.Literal("tab")], {
          description: "Open in a split pane or new tab. Defaults to split pane.",
        })
      ),
    }),
    async execute(_id, params) {
      const repo = repoArg(params.repo);
      const args = ["diff"];
      if (params.staged) args.push("--staged");
      if (params.watch) args.push("--watch");
      if (params.excludeUntracked) args.push("--exclude-untracked");
      if (params.target) args.push(params.target);
      if (params.pathspecs?.length) args.push("--", ...params.pathspecs);
      const result = await openHunkInHerdr(pi, repo, params.placement ?? "pane", args);
      const markerPath = await writePiLastTurnMarker(pi, repo, {
        range: params.target,
        staged: params.staged,
        pathspecs: params.pathspecs,
      });
      return textResult(result.stdout || "Opened Hunk diff review in Herdr.", {
        action: "diff",
        args,
        markerPath,
        ...result,
        transport: "herdr pane run",
      });
    },
  });

  pi.registerTool({
    name: "hunk_reload",
    label: "Hunk Reload",
    description: "Reload the active Hunk session for a repo with a diff or show source.",
    parameters: Type.Object({
      repo: Type.Optional(
        Type.String({ description: "Repository path. Defaults to Pi's current working directory." })
      ),
      source: Type.Optional(
        Type.Union([Type.Literal("diff"), Type.Literal("show")], {
          description: "Reload source command. Defaults to diff.",
        })
      ),
      target: Type.Optional(Type.String({ description: "Optional ref/target for diff/show." })),
      pathspecs: Type.Optional(Type.Array(Type.String(), { description: "Optional pathspecs." })),
    }),
    async execute(_id, params) {
      const repo = repoArg(params.repo);
      const source = params.source ?? "diff";
      const args = ["session", "reload", "--repo", repo, "--", source];
      if (params.target) args.push(params.target);
      if (params.pathspecs?.length) args.push("--", ...params.pathspecs);
      const result = await runCommand(pi, "hunk", args, { cwd: repo });
      const markerPath =
        source === "diff"
          ? await writePiLastTurnMarker(pi, repo, {
              range: params.target,
              pathspecs: params.pathspecs,
            })
          : undefined;
      const parsed = parseJson(result.stdout);
      return textResult(stringify(parsed) || "Reloaded Hunk session.", {
        action: "reload",
        args,
        markerPath,
        parsed,
        ...result,
      });
    },
  });

  pi.registerTool({
    name: "hunk_review",
    label: "Hunk Review",
    description:
      "Read the active Hunk review/session for a repo, optionally including patch and reviewer notes/comments.",
    parameters: Type.Object({
      repo: Type.Optional(
        Type.String({ description: "Repository path. Defaults to Pi's current working directory." })
      ),
      includePatch: Type.Optional(Type.Boolean({ description: "Include patch text." })),
      includeNotes: Type.Optional(Type.Boolean({ description: "Include review notes/comments." })),
      contextOnly: Type.Optional(
        Type.Boolean({ description: "Return session context instead of review." })
      ),
    }),
    async execute(_id, params) {
      const repo = repoArg(params.repo);
      const args = params.contextOnly
        ? ["session", "context", "--repo", repo]
        : ["session", "review", "--repo", repo];
      if (!params.contextOnly) {
        if (params.includePatch) args.push("--include-patch");
        if (params.includeNotes) args.push("--include-notes");
      }
      const result = await runCommand(pi, "hunk", args, { cwd: repo });
      const parsed = parseJson(result.stdout);
      return textResult(stringify(parsed) || "No Hunk review content.", {
        action: params.contextOnly ? "context" : "review",
        args,
        parsed,
        ...result,
      });
    },
  });

  pi.registerTool({
    name: "hunk_comments",
    label: "Hunk Comments",
    description: "List, apply, clear, or remove Hunk review comments for the active repo session.",
    parameters: Type.Object({
      action: Type.Union([
        Type.Literal("list"),
        Type.Literal("apply"),
        Type.Literal("clear"),
        Type.Literal("remove"),
      ]),
      repo: Type.Optional(
        Type.String({ description: "Repository path. Defaults to Pi's current working directory." })
      ),
      type: Type.Optional(
        Type.Union(
          [
            Type.Literal("live"),
            Type.Literal("all"),
            Type.Literal("ai"),
            Type.Literal("agent"),
            Type.Literal("user"),
          ],
          { description: "Comment type filter for list." }
        )
      ),
      commentId: Type.Optional(Type.String({ description: "Comment id for remove." })),
      payload: Type.Optional(
        Type.String({ description: "JSON/text payload for `hunk session comment apply --stdin`." })
      ),
    }),
    async execute(_id, params) {
      const repo = repoArg(params.repo);
      const commentCommand = params.action === "remove" ? "rm" : params.action;
      const args = ["session", "comment", commentCommand, "--repo", repo];
      let stdin: string | undefined;
      if (params.action === "list" && params.type) args.push("--type", params.type);
      if (params.action === "apply") {
        if (!params.payload) throw new Error("payload is required for hunk_comments action=apply");
        args.push("--stdin");
        stdin = params.payload;
      }
      if (params.action === "clear") args.push("--yes");
      if (params.action === "remove") {
        if (!params.commentId)
          throw new Error("commentId is required for hunk_comments action=remove");
        args.push(params.commentId);
      }
      const result = await runCommand(pi, "hunk", args, { cwd: repo, stdin });
      const parsed = parseJson(result.stdout);
      return textResult(stringify(parsed) || `Hunk comments ${params.action} completed.`, {
        action: `comments.${params.action}`,
        args,
        parsed,
        ...result,
      });
    },
  });

  pi.registerTool({
    name: "hunk_commit",
    label: "Hunk Commit",
    description:
      "Create a local Git commit for a Hunk-reviewed changeset, optionally staging unstaged changes and pushing after commit.",
    parameters: Type.Object({
      repo: Type.Optional(
        Type.String({ description: "Repository path. Defaults to Pi's current working directory." })
      ),
      message: Type.String({ description: "Required git commit message." }),
      includeUnstaged: Type.Optional(
        Type.Boolean({ description: "Run `git add -A` before committing." })
      ),
      push: Type.Optional(
        Type.Boolean({ description: "Run `git push` after a successful commit." })
      ),
    }),
    async execute(_id, params) {
      const repo = repoArg(params.repo);
      const message = params.message.trim();
      if (!message) throw new Error("message is required for hunk_commit");

      const commands: Array<{ command: string; args: string[]; stdout: string; stderr: string }> =
        [];

      if (params.includeUnstaged) {
        const staged = await runCommand(pi, "git", ["add", "-A"], { cwd: repo });
        commands.push({ command: "git", args: ["add", "-A"], ...staged });
      }

      const committed = await runCommand(pi, "git", ["commit", "-m", message], { cwd: repo });
      commands.push({ command: "git", args: ["commit", "-m", message], ...committed });

      if (params.push) {
        const pushed = await runCommand(pi, "git", ["push"], { cwd: repo });
        commands.push({ command: "git", args: ["push"], ...pushed });
      }

      return textResult(committed.stdout || committed.stderr || "Committed changes.", {
        action: "commit",
        repo,
        pushed: params.push === true,
        commands,
      });
    },
  });
}
