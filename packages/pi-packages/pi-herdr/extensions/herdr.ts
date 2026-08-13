import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { mkdir, readFile, rename, stat, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
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

export type PrInfo = {
  number: number;
  title: string;
  baseRefName: string;
  headRefName: string;
  headRefOid: string;
  url: string;
};

type ReviewWorkspaceParams = {
  pr: string;
  repo?: string;
  base?: string;
  worktreeName?: string;
  prompt?: string;
  agent?: "omp" | "pi";
};

type ReviewBoxManifest = {
  schemaVersion: 1;
  repoRoot: string;
  prNumber: number;
  prUrl: string;
  headRefOid: string;
  worktreePath: string;
  workspaceId: string;
  diffTarget: string;
  agent: "omp" | "pi";
  updatedAt: string;
};

export type ReviewBoxResult = {
  action: "created" | "restored" | "resumed" | "refreshed";
  pr: PrInfo;
  worktreePath: string;
  workspaceId: string;
  diffTarget: string;
  agent: "omp" | "pi";
};

type ReviewBoxOptions = {
  stateRoot?: string;
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
  const { number, title, baseRefName, headRefName, headRefOid, url } = parsed;
  if (
    typeof number !== "number" ||
    typeof title !== "string" ||
    typeof baseRefName !== "string" ||
    typeof headRefName !== "string" ||
    typeof headRefOid !== "string" ||
    typeof url !== "string"
  ) {
    throw new Error("gh pr view returned incomplete PR metadata");
  }
  return { number, title, baseRefName, headRefName, headRefOid, url };
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

const pathExists = async (path: string): Promise<boolean> =>
  stat(path)
    .then(() => true)
    .catch(() => false);

const hunkDiffCommand = (diffTarget: string): string =>
  [
    "if command -v hunk >/dev/null 2>&1; then",
    `exec hunk diff ${shellQuote(diffTarget)} --no-transparent-bg;`,
    "fi;",
    `exec bunx hunkdiff diff ${shellQuote(diffTarget)} --no-transparent-bg`,
  ].join(" ");

const critiqueDiffCommand = (diffBase: string): string =>
  `exec critique ${shellQuote(diffBase)} HEAD`;

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

const defaultStateRoot = (): string =>
  join(
    process.env.XDG_STATE_HOME ?? join(homedir(), ".local", "state"),
    "pi-herdr",
    "review-boxes"
  );

const manifestPathFor = (pr: PrInfo, stateRoot: string): string => {
  const url = new URL(pr.url);
  const repo = url.pathname.replace(/\/pull\/\d+\/?$/, "");
  const key = slugify(`${repo}-pr-${pr.number}`) || `pr-${pr.number}`;
  return join(stateRoot, `${key}.json`);
};

const isReviewBoxManifest = (value: unknown): value is ReviewBoxManifest =>
  isRecord(value) &&
  value.schemaVersion === 1 &&
  typeof value.repoRoot === "string" &&
  typeof value.prNumber === "number" &&
  typeof value.prUrl === "string" &&
  typeof value.headRefOid === "string" &&
  typeof value.worktreePath === "string" &&
  typeof value.workspaceId === "string" &&
  typeof value.diffTarget === "string" &&
  (value.agent === "omp" || value.agent === "pi") &&
  typeof value.updatedAt === "string";

const readManifest = async (path: string): Promise<ReviewBoxManifest | undefined> => {
  try {
    const parsed: unknown = JSON.parse(await readFile(path, "utf8"));
    if (!isReviewBoxManifest(parsed)) throw new Error(`invalid Review Box manifest: ${path}`);
    return parsed;
  } catch (error) {
    if (isRecord(error) && error.code === "ENOENT") return undefined;
    throw error;
  }
};

const writeManifest = async (path: string, manifest: ReviewBoxManifest): Promise<void> => {
  await mkdir(dirname(path), { recursive: true });
  const temporary = `${path}.${process.pid}.tmp`;
  await writeFile(temporary, `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600 });
  await rename(temporary, path);
};

const workspaceExists = async (pi: ExtensionAPI, workspaceId: string): Promise<boolean> =>
  runHerdr(pi, ["workspace", "get", workspaceId])
    .then(() => true)
    .catch(() => false);

const refreshCheckout = async (
  pi: ExtensionAPI,
  repoRoot: string,
  worktreePath: string,
  pr: PrInfo,
  target: string,
  customBase: boolean
): Promise<void> => {
  if (!customBase) {
    await runCommand(pi, "git", ["fetch", "origin", pr.baseRefName], {
      cwd: repoRoot,
      timeout: 60_000,
    });
  }
  await runCommand(pi, "gh", ["pr", "checkout", target, "--detach", "--force"], {
    cwd: worktreePath,
    timeout: 60_000,
  });
};

const createReviewWorkspace = async (
  pi: ExtensionAPI,
  input: {
    pr: PrInfo;
    worktreePath: string;
    diffBase: string;
    diffTarget: string;
    prompt?: string;
    agent: "omp" | "pi";
  }
): Promise<string> => {
  const workspaceLabel = truncate(`PR #${input.pr.number} ${input.pr.title}`, 56);
  const workspace = await runHerdr(pi, [
    "workspace",
    "create",
    "--cwd",
    input.worktreePath,
    "--label",
    workspaceLabel,
    "--env",
    "HERDR_REVIEW_BOX=1",
    "--focus",
  ]);
  const workspaceId = findStringKey(parseJson(workspace.stdout), new Set(["workspace_id", "id"]));
  if (!workspaceId) throw new Error("could not find workspace id in Herdr response");

  const reviewPrompt = `${buildReviewPrompt({
    pr: input.pr,
    repo: input.worktreePath,
    diffTarget: input.diffTarget,
    hunkTab: "Hunk",
  })}${input.prompt ? `\n\nExtra instruction:\n${input.prompt}` : ""}`;
  const reviewCommand =
    input.agent === "pi"
      ? `pi ${shellQuote(reviewPrompt)}`
      : `omp --cwd ${shellQuote(input.worktreePath)} ${shellQuote(reviewPrompt)}`;

  await createTabAndRun(
    pi,
    workspaceId,
    input.worktreePath,
    "Hunk",
    hunkDiffCommand(input.diffTarget)
  );
  await createTabAndRun(
    pi,
    workspaceId,
    input.worktreePath,
    "Critique",
    critiqueDiffCommand(input.diffBase)
  );
  await createTabAndRun(
    pi,
    workspaceId,
    input.worktreePath,
    input.agent === "pi" ? "Pi Review" : "OMP Review",
    reviewCommand
  );
  await createTabAndRun(
    pi,
    workspaceId,
    input.worktreePath,
    "Approve",
    buildApprovalCommand(input.pr.url)
  );
  await runHerdr(pi, ["workspace", "focus", workspaceId]);
  return workspaceId;
};

export const openPrReviewWorkspace = async (
  pi: ExtensionAPI,
  params: ReviewWorkspaceParams,
  startCwd: string,
  options: ReviewBoxOptions = {}
): Promise<ReviewBoxResult> => {
  const repoRoot = (
    await runCommand(pi, "git", ["rev-parse", "--show-toplevel"], { cwd: params.repo ?? startCwd })
  ).stdout;
  const pr = parsePrInfo(
    (
      await runCommand(
        pi,
        "gh",
        ["pr", "view", params.pr, "--json", "number,title,baseRefName,headRefName,headRefOid,url"],
        { cwd: repoRoot, timeout: 30_000 }
      )
    ).stdout
  );
  const gitCommonDir = (
    await runCommand(pi, "git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], {
      cwd: repoRoot,
    })
  ).stdout;
  const sharedRoot = basename(gitCommonDir) === ".git" ? dirname(gitCommonDir) : repoRoot;
  const stateRoot = options.stateRoot ?? defaultStateRoot();
  const manifestPath = manifestPathFor(pr, stateRoot);
  const manifest = await readManifest(manifestPath);
  const diffBase = params.base ?? `origin/${pr.baseRefName}`;
  const diffTarget = `${diffBase}...HEAD`;
  const agent = params.agent ?? manifest?.agent ?? "omp";

  if (
    manifest &&
    manifest.repoRoot === sharedRoot &&
    manifest.prNumber === pr.number &&
    (await pathExists(manifest.worktreePath))
  ) {
    const exists = await workspaceExists(pi, manifest.workspaceId);
    const headChanged = manifest.headRefOid !== pr.headRefOid;
    if (headChanged) {
      await refreshCheckout(
        pi,
        repoRoot,
        manifest.worktreePath,
        pr,
        params.pr,
        Boolean(params.base)
      );
      if (exists) await runHerdr(pi, ["workspace", "close", manifest.workspaceId]);
      const workspaceId = await createReviewWorkspace(pi, {
        pr,
        worktreePath: manifest.worktreePath,
        diffBase,
        diffTarget,
        prompt: params.prompt,
        agent,
      });
      await writeManifest(manifestPath, {
        ...manifest,
        headRefOid: pr.headRefOid,
        workspaceId,
        diffTarget,
        agent,
        updatedAt: new Date().toISOString(),
      });
      return {
        action: "refreshed",
        pr,
        worktreePath: manifest.worktreePath,
        workspaceId,
        diffTarget,
        agent,
      };
    }
    if (exists) {
      await runHerdr(pi, ["workspace", "focus", manifest.workspaceId]);
      await writeManifest(manifestPath, {
        ...manifest,
        diffTarget,
        agent,
        updatedAt: new Date().toISOString(),
      });
      return {
        action: "resumed",
        pr,
        worktreePath: manifest.worktreePath,
        workspaceId: manifest.workspaceId,
        diffTarget,
        agent,
      };
    }

    const workspaceId = await createReviewWorkspace(pi, {
      pr,
      worktreePath: manifest.worktreePath,
      diffBase,
      diffTarget,
      prompt: params.prompt,
      agent,
    });
    await writeManifest(manifestPath, {
      ...manifest,
      headRefOid: pr.headRefOid,
      workspaceId,
      diffTarget,
      agent,
      updatedAt: new Date().toISOString(),
    });
    return {
      action: "restored",
      pr,
      worktreePath: manifest.worktreePath,
      workspaceId,
      diffTarget,
      agent,
    };
  }

  if (manifest && (await workspaceExists(pi, manifest.workspaceId))) {
    await runHerdr(pi, ["workspace", "close", manifest.workspaceId]);
  }

  const requestedSlug = truncate(
    slugify(params.worktreeName ?? `pr-${pr.number}-${pr.headRefName}`) || `pr-${pr.number}`,
    60
  );
  const worktreePath = join(sharedRoot, ".pi", "worktrees", requestedSlug);
  if (!params.base) {
    await runCommand(pi, "git", ["fetch", "origin", pr.baseRefName], {
      cwd: repoRoot,
      timeout: 60_000,
    });
  }
  if (!(await pathExists(worktreePath))) {
    await mkdir(dirname(worktreePath), { recursive: true });
    await runCommand(pi, "git", ["worktree", "add", "--detach", worktreePath, diffBase], {
      cwd: repoRoot,
      timeout: 60_000,
    });
  }
  await refreshCheckout(pi, repoRoot, worktreePath, pr, params.pr, true);

  const workspaceId = await createReviewWorkspace(pi, {
    pr,
    worktreePath,
    diffBase,
    diffTarget,
    prompt: params.prompt,
    agent,
  });
  await writeManifest(manifestPath, {
    schemaVersion: 1,
    repoRoot: sharedRoot,
    prNumber: pr.number,
    prUrl: pr.url,
    headRefOid: pr.headRefOid,
    worktreePath,
    workspaceId,
    diffTarget,
    agent,
    updatedAt: new Date().toISOString(),
  });
  return { action: "created", pr, worktreePath, workspaceId, diffTarget, agent };
};

const reviewBoxSummary = (result: ReviewBoxResult): string =>
  [
    `${result.action[0]?.toUpperCase()}${result.action.slice(1)} Herdr Review Box for PR #${result.pr.number}.`,
    `Worktree: ${result.worktreePath}`,
    `Diff: ${result.diffTarget}`,
    `Tabs: Hunk, Critique, ${result.agent === "pi" ? "Pi Review" : "OMP Review"}, Approve`,
  ].join("\n");

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
      agent: Type.Optional(
        Type.Union([Type.Literal("omp"), Type.Literal("pi")], {
          description: "Review agent tab. Defaults to OMP; Pi is an explicit override.",
        })
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const startCwd = params.repo ?? ctx?.cwd ?? process.cwd();
      const result = await openPrReviewWorkspace(pi, params, startCwd);
      return textResult(reviewBoxSummary(result), result);
    },
  });

  pi.registerCommand("review-box", {
    description: "Create or resume one Herdr Review Box for a GitHub pull request",
    handler: async (args, ctx) => {
      const argv = args.trim().split(/\s+/).filter(Boolean);
      const pr = argv[0];
      if (!pr) {
        ctx.ui.notify("Usage: /review-box <pr-number|url|branch> [--agent omp|pi]", "info");
        return;
      }
      const agentIndex = argv.indexOf("--agent");
      const agentValue = agentIndex >= 0 ? argv[agentIndex + 1] : undefined;
      if (agentValue !== undefined && agentValue !== "omp" && agentValue !== "pi") {
        ctx.ui.notify("--agent must be omp or pi", "error");
        return;
      }
      const agent = agentValue === "pi" ? "pi" : agentValue === "omp" ? "omp" : undefined;
      try {
        const result = await openPrReviewWorkspace(pi, { pr, agent }, ctx.cwd);
        ctx.ui.notify(reviewBoxSummary(result), "info");
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
      }
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
