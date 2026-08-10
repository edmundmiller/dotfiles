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
  const patchPath = await gitPath(pi, repo, "hunk/last-pi-turn.patch");
  const diffArgs = ["diff"];
  if (input.staged) diffArgs.push("--staged");
  if (input.range) diffArgs.push(input.range);
  if (input.pathspecs?.length) diffArgs.push("--", ...input.pathspecs);
  const diff = await runCommand(pi, "git", diffArgs, { cwd: repo });
  await mkdir(dirname(markerPath), { recursive: true });
  await writeFile(patchPath, `${diff.stdout}\n`);
  await writeFile(
    markerPath,
    `${JSON.stringify(
      {
        version: 1,
        source: "pi-hunk",
        createdAt: new Date().toISOString(),
        kind: "patch",
        file: patchPath,
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
async function devLayoutScript(pi: ExtensionAPI): Promise<string> {
  const result = await runCommand(pi, "herdr", ["plugin", "list", "--json"]);
  const payload = JSON.parse(result.stdout) as {
    result?: { plugins?: Array<{ id?: string; plugin_id?: string; manifest_path?: string }> };
  };
  const plugin = payload.result?.plugins?.find(
    (entry) => (entry.id ?? entry.plugin_id) === "dotfiles.dev-layout"
  );
  if (!plugin?.manifest_path) {
    throw new Error("dotfiles.dev-layout Herdr plugin is not installed");
  }
  return join(dirname(plugin.manifest_path), "dev_layout.py");
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
      const markerPath = await writePiLastTurnMarker(pi, repo, {
        range: params.target,
        staged: params.staged,
        pathspecs: params.pathspecs,
      });
      // Drive the dev-layout plugin script directly so diff options survive;
      // `herdr plugin action invoke` cannot forward arguments. The script
      // resolves workspace/pane from HERDR_* env inherited by Pi's pane.
      const script = await devLayoutScript(pi);
      const args = [script, "hunk", params.placement === "tab" ? "--tab" : "--split"];
      if (params.staged) args.push("--staged");
      const passthrough: string[] = [];
      if (params.watch) passthrough.push("--watch");
      if (params.excludeUntracked) passthrough.push("--exclude-untracked");
      if (params.target) passthrough.push(params.target);
      if (params.pathspecs?.length) passthrough.push("--", ...params.pathspecs);
      if (passthrough.length) args.push("--", ...passthrough);
      const result = await runCommand(pi, "python3", args, {
        cwd: repo,
        timeout: 10_000,
      });
      return textResult(result.stdout || "Opened Hunk diff review in Herdr.", {
        action: "diff",
        command: "python3",
        args,
        markerPath,
        ...result,
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
