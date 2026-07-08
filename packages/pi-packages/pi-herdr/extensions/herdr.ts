import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { basename, dirname, join } from "node:path";

const HERDR_TIMEOUT_MS = 10_000;

const stringify = (value: unknown): string =>
  typeof value === "string" ? value : JSON.stringify(value, null, 2);

const textResult = (text: string, details: Record<string, unknown> = {}) => ({
  content: [{ type: "text" as const, text }],
  details,
});

const runHerdr = async (
  pi: ExtensionAPI,
  args: string[],
  options: { cwd?: string; timeout?: number } = {}
) => {
  const result = await pi.exec("herdr", args, {
    cwd: options.cwd ?? process.cwd(),
    timeout: options.timeout ?? HERDR_TIMEOUT_MS,
  });

  const stdout = result.stdout?.trim() ?? "";
  const stderr = result.stderr?.trim() ?? "";

  if (result.code !== 0) {
    throw new Error(
      [`herdr ${args.join(" ")} failed with exit code ${result.code}`, stdout, stderr]
        .filter(Boolean)
        .join("\n\n")
    );
  }

  return { stdout, stderr, code: result.code };
};

const runCommand = async (
  pi: ExtensionAPI,
  command: string,
  args: string[],
  options: { cwd?: string; timeout?: number } = {}
) => {
  const result = await pi.exec(command, args, {
    cwd: options.cwd ?? process.cwd(),
    timeout: options.timeout ?? HERDR_TIMEOUT_MS,
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
};

const parseJson = (text: string): unknown => {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
};

type PrInfo = {
  number: number;
  title: string;
  baseRefName: string;
  headRefName: string;
  url: string;
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

export const slugify = (value: string): string =>
  value
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/-+/g, "-");

const truncate = (value: string, maxLength: number): string =>
  value.length <= maxLength ? value : value.slice(0, maxLength).replace(/-+$/g, "");

const shellQuote = (value: string): string => `'${value.replace(/'/g, "'\\''")}'`;

const parsePrInfo = (stdout: string): PrInfo => {
  const parsed: unknown = JSON.parse(stdout);
  if (!isRecord(parsed)) throw new Error("gh pr view returned non-object JSON");
  const { number, title, baseRefName, headRefName, url } = parsed;
  if (
    typeof number !== "number" ||
    typeof title !== "string" ||
    typeof baseRefName !== "string" ||
    typeof headRefName !== "string" ||
    typeof url !== "string"
  ) {
    throw new Error("gh pr view returned incomplete PR metadata");
  }
  return { number, title, baseRefName, headRefName, url };
};

export const findStringKey = (value: unknown, keys: Set<string>): string | undefined => {
  if (Array.isArray(value)) {
    for (const item of value) {
      const found = findStringKey(item, keys);
      if (found) return found;
    }
    return undefined;
  }
  if (!isRecord(value)) return undefined;
  for (const [key, item] of Object.entries(value)) {
    if (keys.has(key) && typeof item === "string" && item) return item;
    const found = findStringKey(item, keys);
    if (found) return found;
  }
  return undefined;
};

const repoStemFromUrl = (url: string): string | undefined => {
  const stem = basename(url).replace(/\.git$/, "");
  return slugify(stem) || undefined;
};

const uniqueName = async (pi: ExtensionAPI, repo: string, prefix: string): Promise<string> => {
  const exists = await pi.exec("git", ["show-ref", "--verify", "--quiet", `refs/heads/${prefix}`], {
    cwd: repo,
    timeout: HERDR_TIMEOUT_MS,
  });
  if (exists.code !== 0) return prefix;
  const stamp = new Date()
    .toISOString()
    .replace(/[-:TZ.]/g, "")
    .slice(0, 14);
  return `${prefix}-${stamp}`;
};

const pathExists = async (pi: ExtensionAPI, path: string): Promise<boolean> => {
  const exists = await pi.exec("test", ["-e", path], { timeout: HERDR_TIMEOUT_MS });
  return exists.code === 0;
};

const hunkDiffCommand = (diffTarget: string): string =>
  [
    "if command -v hunk >/dev/null 2>&1; then",
    `exec hunk diff ${shellQuote(diffTarget)} --no-transparent-bg;`,
    "fi;",
    `exec bunx hunkdiff diff ${shellQuote(diffTarget)} --no-transparent-bg`,
  ].join(" ");

export const buildReviewPrompt = (input: {
  pr: PrInfo;
  repo: string;
  diffTarget: string;
  hunkTab: string;
}): string =>
  [
    "/review",
    "",
    `Review PR #${input.pr.number}: ${input.pr.title}`,
    `URL: ${input.pr.url}`,
    `Repo: ${input.repo}`,
    `Diff: ${input.diffTarget}`,
    "",
    `A Herdr tab named ${input.hunkTab} is open with the Hunk diff.`,
    "Use Hunk as the review surface.",
    "Start with hunk session review --repo . --json, then include patches only as needed.",
    "Leave inline Hunk comments for actionable findings using hunk_comments action=apply or hunk session comment apply.",
    "Prioritize bugs, regressions, missing tests, and merge risks.",
    "Do not edit code unless asked.",
    "End with an approve/request-changes recommendation.",
  ].join("\n");

export const buildApprovalCommand = (prUrl: string): string =>
  [
    "printf '%s\\n' 'Review actions:'",
    `printf '%s\\n' '  gh pr review ${prUrl} --approve'`,
    `printf '%s\\n' '  gh pr review ${prUrl} --request-changes -b \"<reason>\"'`,
    `printf '%s\\n' '  gh pr review ${prUrl} --comment -b \"<summary>\"'`,
    `printf '%s\\n' '  gh pr view ${prUrl} --web'`,
    "exec ${SHELL:-/bin/zsh} -l",
  ].join("; ");

const createTabAndRun = async (
  pi: ExtensionAPI,
  workspaceId: string,
  cwd: string,
  label: string,
  command: string
) => {
  const tab = await runHerdr(pi, [
    "tab",
    "create",
    "--workspace",
    workspaceId,
    "--cwd",
    cwd,
    "--label",
    label,
    "--no-focus",
  ]);
  const paneId = findStringKey(parseJson(tab.stdout), new Set(["pane_id"]));
  if (!paneId) throw new Error(`could not find pane_id for ${label} tab`);
  await runHerdr(pi, ["pane", "rename", paneId, label]);
  await runHerdr(pi, ["pane", "run", paneId, command]);
  return paneId;
};

export default function herdrExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "herdr_status",
    label: "Herdr Status",
    description: "Check the local herdr client/server status and socket compatibility.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const result = await runHerdr(pi, ["status"]);
      return textResult(result.stdout || "herdr status returned no output", result);
    },
  });

  pi.registerTool({
    name: "herdr_list",
    label: "Herdr List",
    description: "List herdr workspaces, tabs, or panes using the running herdr server.",
    parameters: Type.Object({
      resource: Type.Union(
        [Type.Literal("workspaces"), Type.Literal("tabs"), Type.Literal("panes")],
        { description: "Which herdr resource to list." }
      ),
      workspaceId: Type.Optional(
        Type.String({ description: "Optional workspace id filter for tabs or panes." })
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const args =
        params.resource === "workspaces"
          ? ["workspace", "list"]
          : params.resource === "tabs"
            ? ["tab", "list"]
            : ["pane", "list"];

      if (params.workspaceId && params.resource !== "workspaces") {
        args.push("--workspace", params.workspaceId);
      }

      const result = await runHerdr(pi, args);
      const parsed = parseJson(result.stdout);
      return textResult(stringify(parsed), { ...result, parsed });
    },
  });

  pi.registerTool({
    name: "herdr_read_pane",
    label: "Herdr Read Pane",
    description: "Read visible or recent output from a herdr pane.",
    parameters: Type.Object({
      paneId: Type.String({ description: "Stable herdr pane id, e.g. w...-1 or positional 1-1." }),
      source: Type.Optional(
        Type.Union(
          [Type.Literal("visible"), Type.Literal("recent"), Type.Literal("recent-unwrapped")],
          { description: "Output source. Defaults to recent." }
        )
      ),
      lines: Type.Optional(
        Type.Number({ description: "Number of lines to read. Defaults to 80; herdr caps at 1000." })
      ),
      ansi: Type.Optional(Type.Boolean({ description: "Preserve ANSI formatting." })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const args = ["pane", "read", params.paneId, "--source", params.source ?? "recent"];
      if (params.lines) args.push("--lines", String(params.lines));
      if (params.ansi) args.push("--ansi");
      const result = await runHerdr(pi, args);
      return textResult(result.stdout || "(pane output empty)", result);
    },
  });

  pi.registerTool({
    name: "herdr_run_in_pane",
    label: "Herdr Run In Pane",
    description: "Send a command to a herdr pane and press Enter via `herdr pane run`.",
    parameters: Type.Object({
      paneId: Type.String({ description: "Target herdr pane id." }),
      command: Type.String({ description: "Command text to send to the pane." }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await runHerdr(pi, ["pane", "run", params.paneId, params.command]);
      return textResult("Command sent to herdr pane.", result);
    },
  });

  pi.registerTool({
    name: "herdr_wait",
    label: "Herdr Wait",
    description: "Wait for pane output to match text/regex or for an agent status transition.",
    parameters: Type.Object({
      kind: Type.Union([Type.Literal("output"), Type.Literal("agent-status")]),
      paneId: Type.String({ description: "Target herdr pane id." }),
      match: Type.Optional(
        Type.String({ description: "Text or regex to match when kind is output." })
      ),
      regex: Type.Optional(
        Type.Boolean({ description: "Treat match as a regex for output waits." })
      ),
      status: Type.Optional(
        Type.Union(
          [
            Type.Literal("idle"),
            Type.Literal("working"),
            Type.Literal("blocked"),
            Type.Literal("done"),
            Type.Literal("unknown"),
          ],
          { description: "Agent status when kind is agent-status." }
        )
      ),
      timeoutMs: Type.Optional(
        Type.Number({ description: "Timeout in milliseconds. Defaults to 60000." })
      ),
      lines: Type.Optional(Type.Number({ description: "Lines to scan for output waits." })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const timeout = String(params.timeoutMs ?? 60_000);
      const args = ["wait", params.kind, params.paneId];

      if (params.kind === "output") {
        if (!params.match) throw new Error("match is required for output waits");
        args.push("--match", params.match, "--timeout", timeout);
        if (params.regex) args.push("--regex");
        if (params.lines) args.push("--lines", String(params.lines));
      } else {
        if (!params.status) throw new Error("status is required for agent-status waits");
        args.push("--status", params.status, "--timeout", timeout);
      }

      const result = await runHerdr(pi, args, { timeout: Number(timeout) + 2_000 });
      const parsed = parseJson(result.stdout);
      return textResult(stringify(parsed), { ...result, parsed });
    },
  });

  pi.registerTool({
    name: "herdr_pr_review_workspace",
    label: "Herdr PR Review Workspace",
    description:
      "Create a PR review git worktree, open a Herdr workspace with Hunk, start an OMP review tab, and add an approval tab.",
    parameters: Type.Object({
      pr: Type.String({
        description: "Pull request number, URL, or branch accepted by `gh pr view`.",
      }),
      repo: Type.Optional(
        Type.String({ description: "Repository path. Defaults to the current OMP/Pi cwd." })
      ),
      base: Type.Optional(
        Type.String({
          description: "Optional base ref for the Hunk diff. Defaults to origin/<PR base>.",
        })
      ),
      worktreeName: Type.Optional(
        Type.String({ description: "Optional worktree slug. Defaults to pr-<number>-<title>." })
      ),
      prompt: Type.Optional(
        Type.String({
          description: "Optional extra instruction appended to the OMP review prompt.",
        })
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const startCwd = params.repo ?? ctx?.cwd ?? process.cwd();
      const repoRoot = (
        await runCommand(pi, "git", ["rev-parse", "--show-toplevel"], { cwd: startCwd })
      ).stdout;
      const pr = parsePrInfo(
        (
          await runCommand(
            pi,
            "gh",
            ["pr", "view", params.pr, "--json", "number,title,baseRefName,headRefName,url"],
            { cwd: repoRoot, timeout: 30_000 }
          )
        ).stdout
      );
      const remote = (
        await runCommand(pi, "git", ["config", "--get", "remote.origin.url"], {
          cwd: repoRoot,
        }).catch(() => ({ stdout: "" }))
      ).stdout;
      const repoStem = repoStemFromUrl(remote) ?? slugify(basename(repoRoot)) ?? "repo";
      const requestedSlug = truncate(
        slugify(params.worktreeName ?? `pr-${pr.number}-${pr.title}`) || `pr-${pr.number}`,
        60
      );
      let branchName = await uniqueName(pi, repoRoot, `review/${requestedSlug}`);
      const pathSlug = branchName.replace(/\//g, "-");
      let worktreePath = join(dirname(repoRoot), `${repoStem}-${pathSlug}`);
      if (await pathExists(pi, worktreePath)) {
        const stamp = new Date()
          .toISOString()
          .replace(/[-:TZ.]/g, "")
          .slice(0, 14);
        branchName = await uniqueName(pi, repoRoot, `review/${requestedSlug}-${stamp}`);
        worktreePath = join(dirname(repoRoot), `${repoStem}-${branchName.replace(/\//g, "-")}`);
      }
      const diffBase = params.base ?? `origin/${pr.baseRefName}`;
      const diffTarget = `${diffBase}...HEAD`;
      const workspaceLabel = truncate(`PR #${pr.number} ${pr.title}`, 56);

      if (!params.base) {
        await runCommand(pi, "git", ["fetch", "origin", pr.baseRefName], {
          cwd: repoRoot,
          timeout: 60_000,
        });
      }
      await runCommand(pi, "git", ["worktree", "add", "--detach", worktreePath, diffBase], {
        cwd: repoRoot,
        timeout: 60_000,
      });
      await runCommand(pi, "gh", ["pr", "checkout", params.pr, "--detach", "--force"], {
        cwd: worktreePath,
        timeout: 60_000,
      });

      const workspace = await runHerdr(pi, [
        "workspace",
        "create",
        "--cwd",
        worktreePath,
        "--label",
        workspaceLabel,
        "--focus",
      ]);
      const workspaceId = findStringKey(
        parseJson(workspace.stdout),
        new Set(["workspace_id", "id"])
      );
      if (!workspaceId) throw new Error("could not find workspace id in Herdr response");

      const hunkCommand = hunkDiffCommand(diffTarget);
      const reviewPrompt = `${buildReviewPrompt({
        pr,
        repo: worktreePath,
        diffTarget,
        hunkTab: "Hunk",
      })}${params.prompt ? `\n\nExtra instruction:\n${params.prompt}` : ""}`;
      const ompCommand = `omp --cwd ${shellQuote(worktreePath)} ${shellQuote(reviewPrompt)}`;

      await createTabAndRun(pi, workspaceId, worktreePath, "Hunk", hunkCommand);
      await createTabAndRun(pi, workspaceId, worktreePath, "OMP Review", ompCommand);
      await createTabAndRun(pi, workspaceId, worktreePath, "Approve", buildApprovalCommand(pr.url));
      await runHerdr(pi, ["workspace", "focus", workspaceId]);

      return textResult(
        [
          `Created Herdr PR review workspace ${workspaceLabel}.`,
          `Worktree: ${worktreePath}`,
          `Diff: ${diffTarget}`,
          "Tabs: Hunk, OMP Review, Approve",
        ].join("\n"),
        { pr, worktreePath, workspaceId, diffTarget }
      );
    },
  });

  pi.registerCommand("herdr", {
    description: "Run a herdr CLI command from inside Pi, e.g. /herdr pane list",
    handler: async (args, ctx) => {
      const argv = args.trim().split(/\s+/).filter(Boolean);
      if (argv.length === 0) {
        ctx.ui.notify("Usage: /herdr <status|workspace|tab|pane|wait ...>", "info");
        return;
      }
      try {
        const result = await runHerdr(pi, argv, { cwd: ctx.cwd, timeout: 30_000 });
        ctx.ui.notify(result.stdout || "herdr command completed", "info");
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
      }
    },
  });
}
