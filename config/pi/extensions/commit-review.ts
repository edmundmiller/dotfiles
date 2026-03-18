/**
 * Commit review extension.
 *
 * Drafts a commit message in a child pi process, then opens `git commit -v`
 * in a real editor so you can review the verbose diff and return to pi on exit.
 *
 * Shortcuts:
 *   Ctrl+Shift+G — draft + review staged commit
 *
 * Commands:
 *   /commit-review [guidance]
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { loadCommitConfig, type CommitConfig } from "./lib/commit-config";
import {
  buildCommitDraftPrompt,
  chooseCommitEditor,
  sanitizeCommitMessage,
  truncateForPrompt,
} from "./lib/commit-review-logic";

interface ModelInfo {
  id: string;
  provider: string;
  cost: {
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
  };
}

interface ModelSelection {
  model: string;
  source: "config" | "current" | "auto";
  cost: ModelInfo["cost"] | null;
}

const DEFAULT_MAX_OUTPUT_COST = 1.0;
const DEFAULT_CONFIG: CommitConfig = {
  mode: "anthropic/claude-haiku-4-5",
  maxOutputCost: DEFAULT_MAX_OUTPUT_COST,
};
const HARD_FALLBACK_MODEL = "github-copilot/gpt-4o-mini";
const MAX_DIFF_CHARS = 32_000;
const MAX_STAT_CHARS = 4_000;
const COMMIT_SHORTCUT = "ctrl+shift+g";

function normalizeMode(mode?: string): string | undefined {
  if (!mode) return undefined;
  const trimmed = mode.trim();
  if (!trimmed) return undefined;
  return /^[^/\s]+\/[^\s]+$/.test(trimmed) ? trimmed : undefined;
}

function calculateCostScore(model: ModelInfo): number {
  const { input, output } = model.cost;
  if (input === 0 && output === 0) return Number.MAX_SAFE_INTEGER;
  return input + output * 2;
}

function isCheapModelName(id: string): boolean {
  return /(mini|flash|nano|haiku|lite|micro|free)/i.test(id);
}

function isModelInfo(value: unknown): value is ModelInfo {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return false;

  const id = Reflect.get(value, "id");
  const provider = Reflect.get(value, "provider");
  const cost = Reflect.get(value, "cost");
  if (typeof id !== "string" || typeof provider !== "string") return false;
  if (typeof cost !== "object" || cost === null || Array.isArray(cost)) return false;

  return (
    typeof Reflect.get(cost, "input") === "number" &&
    typeof Reflect.get(cost, "output") === "number" &&
    typeof Reflect.get(cost, "cacheRead") === "number" &&
    typeof Reflect.get(cost, "cacheWrite") === "number"
  );
}

async function getAvailableModels(ctx: ExtensionContext): Promise<ModelInfo[]> {
  const available = await ctx.modelRegistry.getAvailable();
  if (!Array.isArray(available)) return [];
  return available.filter(isModelInfo);
}

async function pickCheapestModel(
  ctx: ExtensionContext,
  maxOutputCost: number
): Promise<ModelSelection> {
  const available = await getAvailableModels(ctx);
  if (available.length === 0) {
    return { model: HARD_FALLBACK_MODEL, source: "auto", cost: null };
  }

  const tokenBased = available.filter(
    (model) => !(model.cost.input === 0 && model.cost.output === 0)
  );

  const cheapModels = tokenBased
    .filter((model) => model.cost.output <= maxOutputCost)
    .sort((left, right) => calculateCostScore(left) - calculateCostScore(right));
  const cheapestUnderCap = cheapModels[0];
  if (cheapestUnderCap) {
    return {
      model: `${cheapestUnderCap.provider}/${cheapestUnderCap.id}`,
      source: "auto",
      cost: cheapestUnderCap.cost,
    };
  }

  const cheapNamed = tokenBased
    .filter((model) => isCheapModelName(model.id))
    .sort((left, right) => calculateCostScore(left) - calculateCostScore(right));
  const cheapestNamed = cheapNamed[0];
  if (cheapestNamed) {
    return {
      model: `${cheapestNamed.provider}/${cheapestNamed.id}`,
      source: "auto",
      cost: cheapestNamed.cost,
    };
  }

  const cheapestTokenBased = [...tokenBased].sort(
    (left, right) => calculateCostScore(left) - calculateCostScore(right)
  )[0];
  if (cheapestTokenBased) {
    return {
      model: `${cheapestTokenBased.provider}/${cheapestTokenBased.id}`,
      source: "auto",
      cost: cheapestTokenBased.cost,
    };
  }

  const cheapestAvailable = [...available].sort(
    (left, right) => calculateCostScore(left) - calculateCostScore(right)
  )[0];
  return {
    model: `${cheapestAvailable.provider}/${cheapestAvailable.id}`,
    source: "auto",
    cost: cheapestAvailable.cost,
  };
}

async function getModelCost(
  ctx: ExtensionContext,
  modelString: string
): Promise<ModelInfo["cost"] | null> {
  const [provider, ...idParts] = modelString.split("/");
  const modelId = idParts.join("/");
  const available = await getAvailableModels(ctx);
  const found = available.find((model) => model.provider === provider && model.id === modelId);
  return found ? found.cost : null;
}

function formatCost(cost: ModelInfo["cost"] | null): string {
  if (!cost) return "cost unknown";
  const prices = [cost.input, cost.output, cost.cacheRead, cost.cacheWrite].filter(
    (price) => price > 0
  );
  if (prices.length === 0) return "request-priced";

  const biggest = Math.max(...prices);
  if (biggest >= 1) return `$${biggest.toFixed(2)}/1M tok max`;
  if (biggest >= 0.1) return `$${biggest.toFixed(3)}/1M tok max`;
  return `$${biggest.toFixed(4)}/1M tok max`;
}

async function resolveModelSelection(ctx: ExtensionContext): Promise<ModelSelection> {
  const config = loadCommitConfig(DEFAULT_CONFIG);
  const maxCost = config.maxOutputCost ?? DEFAULT_MAX_OUTPUT_COST;
  const configured = normalizeMode(config.mode);

  if (configured) {
    const cost = await getModelCost(ctx, configured);
    return { model: configured, source: "config", cost };
  }

  if (ctx.model) {
    return {
      model: `${ctx.model.provider}/${ctx.model.id}`,
      source: "current",
      cost: ctx.model.cost,
    };
  }

  return pickCheapestModel(ctx, maxCost);
}

async function isGitRepo(pi: ExtensionAPI, cwd: string): Promise<boolean> {
  const result = await pi.exec("git", ["rev-parse", "--is-inside-work-tree"], {
    cwd,
    timeout: 5_000,
  });
  return result.code === 0 && result.stdout.trim() === "true";
}

async function hasStagedChanges(pi: ExtensionAPI, cwd: string): Promise<boolean> {
  const result = await pi.exec("git", ["diff", "--cached", "--quiet"], { cwd, timeout: 5_000 });
  return result.code === 1;
}

async function readStagedStat(pi: ExtensionAPI, cwd: string): Promise<string> {
  const result = await pi.exec("git", ["diff", "--cached", "--stat"], { cwd, timeout: 10_000 });
  return result.stdout.trim();
}

async function readStagedDiff(pi: ExtensionAPI, cwd: string): Promise<string> {
  const semantic = await pi.exec("diffs", ["--staged"], { cwd, timeout: 20_000 });
  if (semantic.code === 0 && semantic.stdout.trim()) {
    return semantic.stdout.trim();
  }

  const fallback = await pi.exec("git", ["diff", "--cached", "--"], { cwd, timeout: 20_000 });
  return fallback.stdout.trim();
}

async function generateCommitDraft(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  guidance: string
): Promise<{ draft: string; selection: ModelSelection }> {
  const selection = await resolveModelSelection(ctx);
  const stagedStat = truncateForPrompt(await readStagedStat(pi, ctx.cwd), MAX_STAT_CHARS);
  const stagedDiff = truncateForPrompt(await readStagedDiff(pi, ctx.cwd), MAX_DIFF_CHARS);
  const prompt = buildCommitDraftPrompt({ stagedStat, stagedDiff, guidance });

  const result = await pi.exec(
    "pi",
    [
      "-p",
      "--no-session",
      "--model",
      selection.model,
      "--no-tools",
      "--append-system-prompt",
      "Reply with raw commit message text only. No commentary, code fences, or quotes.",
      prompt,
    ],
    {
      cwd: ctx.cwd,
      timeout: 180_000,
    }
  );

  if (result.code !== 0) {
    const details = result.stderr.trim() || result.stdout.trim() || "child pi failed";
    throw new Error(details);
  }

  const draft = sanitizeCommitMessage(result.stdout);
  if (!draft) {
    throw new Error("child pi returned an empty commit message");
  }

  return { draft, selection };
}

function launchCommitEditor(cwd: string, draft: string, editor: string) {
  return (
    tui: { stop: () => void; start: () => void; requestRender: (force?: boolean) => void },
    _theme: unknown,
    _kb: unknown,
    done: (status: number | null) => void
  ) => {
    tui.stop();
    process.stdout.write("\x1b[2J\x1b[H");

    const dir = mkdtempSync(path.join(tmpdir(), "pi-commit-review-"));
    const templatePath = path.join(dir, "COMMIT_EDITMSG");
    writeFileSync(templatePath, `${draft.trim()}\n`, "utf8");

    const result = spawnSync("git", ["commit", "--verbose", "--template", templatePath], {
      stdio: "inherit",
      cwd,
      env: {
        ...process.env,
        GIT_EDITOR: editor,
        GIT_SEQUENCE_EDITOR: editor,
      },
    });

    rmSync(dir, { recursive: true, force: true });
    tui.start();
    tui.requestRender(true);
    done(result.status);

    return { render: () => [], invalidate: () => {} };
  };
}

async function runCommitReview(
  args: string,
  ctx: ExtensionContext,
  pi: ExtensionAPI
): Promise<void> {
  if (!ctx.hasUI) {
    ctx.ui.notify("commit review requires interactive TUI mode", "error");
    return;
  }

  if (!ctx.isIdle()) {
    ctx.ui.notify("wait for pi to go idle first", "warning");
    return;
  }

  if (!(await isGitRepo(pi, ctx.cwd))) {
    ctx.ui.notify("not inside a git repository", "error");
    return;
  }

  if (!(await hasStagedChanges(pi, ctx.cwd))) {
    ctx.ui.notify("no staged changes; stage the commit first", "warning");
    return;
  }

  ctx.ui.notify("drafting commit message in child pi...", "info");

  let draft: string;
  let selection: ModelSelection;
  try {
    const generated = await generateCommitDraft(pi, ctx, args);
    draft = generated.draft;
    selection = generated.selection;
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown error";
    ctx.ui.notify(`commit draft failed: ${message}`, "error");
    return;
  }

  const subject = draft.split("\n")[0]?.trim() || draft.trim();
  const sourceLabel = selection.source === "config" ? "configured" : selection.source;
  ctx.ui.notify(
    `draft ready via ${selection.model} [${sourceLabel}] — ${formatCost(selection.cost)}`,
    "info"
  );
  ctx.ui.notify(subject, "success");

  const editor = chooseCommitEditor(process.env);
  const status = await ctx.ui.custom<number | null>(launchCommitEditor(ctx.cwd, draft, editor));

  if (status === 0) {
    ctx.ui.notify("commit created", "success");
  } else {
    ctx.ui.notify("commit aborted", "warning");
  }
}

export default function commitReviewExtension(pi: ExtensionAPI) {
  pi.registerShortcut(COMMIT_SHORTCUT, {
    description: "Draft + review staged commit in editor",
    handler: async (ctx) => {
      await runCommitReview("", ctx, pi);
    },
  });

  pi.registerCommand("commit-review", {
    description: "Draft a staged commit message in child pi, then open git commit -v",
    handler: async (args: string, ctx: ExtensionContext) => {
      await runCommitReview(args, ctx, pi);
    },
  });
}
