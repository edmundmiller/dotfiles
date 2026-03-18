/**
 * Review extension — Pi-native diff cockpit for changed files.
 *
 * Shortcuts:
 *   Ctrl+Shift+V — open native review screen
 *
 * Commands:
 *   /diff-review [--staged]
 *   /review-staged
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { spawnSync } from "node:child_process";
import {
  buildEditorOpenCommand,
  chooseReviewEditor,
  loadReviewData,
  type ReviewMode,
} from "./lib/review-git";
import {
  ReviewScreen,
  type ReviewScreenResult,
  type ReviewScreenSnapshot,
} from "./lib/review-screen";

interface BlockingTuiController {
  stop(): void;
  start(): void;
  requestRender(force?: boolean): void;
}

function parseReviewMode(args: string): ReviewMode {
  const tokens = args.trim().split(/\s+/).filter(Boolean);

  for (const token of tokens) {
    if (token === "--staged" || token === "--cached" || token === "staged") return "staged";
  }

  return "worktree";
}

function launchEditor(cwd: string, command: string) {
  return (
    tui: BlockingTuiController,
    _theme: unknown,
    _kb: unknown,
    done: (status: number | null) => void
  ) => {
    tui.stop();
    process.stdout.write("\x1b[2J\x1b[H");

    const result = spawnSync("sh", ["-lc", command], {
      stdio: "inherit",
      cwd,
      env: { ...process.env },
    });

    tui.start();
    tui.requestRender(true);
    done(result.status);

    return { render: () => [], invalidate: () => {} };
  };
}

async function runReview(
  ctx: ExtensionContext,
  pi: ExtensionAPI,
  initialMode: ReviewMode
): Promise<void> {
  if (!ctx.hasUI) {
    ctx.ui.notify("review requires interactive TUI mode", "error");
    return;
  }

  if (!ctx.isIdle()) {
    ctx.ui.notify("wait for pi to go idle first", "warning");
    return;
  }

  let snapshot: ReviewScreenSnapshot | undefined;
  const mode = initialMode;

  while (true) {
    let data;
    try {
      data = await loadReviewData(pi, ctx.cwd, mode);
    } catch (error) {
      const message = error instanceof Error ? error.message : "failed to load git review data";
      ctx.ui.notify(message, "error");
      return;
    }

    if (data.files.length === 0) {
      const label = mode === "staged" ? "staged changes" : "working tree changes";
      ctx.ui.notify(`no ${label} to review`, "info");
      return;
    }

    const result = await ctx.ui.custom<ReviewScreenResult>(
      (tui, theme, _kb, done) => new ReviewScreen(tui, theme, data, done, snapshot)
    );
    snapshot = result.snapshot;

    if (result.action === "close") return;

    const editor = chooseReviewEditor(process.env);
    const command = buildEditorOpenCommand(editor, result.filePath, result.line);
    const status = await ctx.ui.custom<number | null>(launchEditor(ctx.cwd, command));
    if (status !== 0 && status !== null) {
      ctx.ui.notify(`editor exited with status ${status}`, "warning");
    }
  }
}

export default function reviewExtension(pi: ExtensionAPI) {
  pi.registerShortcut("ctrl+shift+v", {
    description: "Open Pi-native review screen",
    handler: async (ctx) => {
      await runReview(ctx, pi, "worktree");
    },
  });

  pi.registerCommand("diff-review", {
    description: "Open Pi-native diff review screen for working tree or staged changes",
    handler: async (args, ctx) => {
      await runReview(ctx, pi, parseReviewMode(args));
    },
  });

  pi.registerCommand("review-staged", {
    description: "Open Pi-native review screen for staged changes",
    handler: async (_args, ctx) => {
      await runReview(ctx, pi, "staged");
    },
  });
}
