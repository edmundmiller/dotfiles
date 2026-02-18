/**
 * Critique Extension — launch critique diff viewer from Pi
 *
 * Shortcuts:
 *   Ctrl+Q — open critique TUI (unstaged diff)
 *   Ctrl+R — open critique TUI (staged diff)
 *
 * Commands:
 *   /critique [args]  — run critique with custom args
 *   /critique-review [args] — run critique review (AI-powered)
 */

import { spawnSync } from "node:child_process";
import { writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";

// critique can't parse difftastic output — provide a minimal gitconfig without diff.external
function getCritiqueGitConfig(): string {
  const p = join(tmpdir(), "critique-gitconfig");
  if (!existsSync(p)) writeFileSync(p, "[user]\n  name = critique\n  email = critique@local\n");
  return p;
}

function launchCritique(cwd: string, args: string[] = []) {
  return (tui: any, _theme: any, _kb: any, done: (result: number | null) => void) => {
    tui.stop();
    process.stdout.write("\x1b[2J\x1b[H");

    const result = spawnSync("bunx", ["critique", ...args], {
      stdio: "inherit",
      env: {
        ...process.env,
        GIT_CONFIG_GLOBAL: getCritiqueGitConfig(),
        GIT_CONFIG_SYSTEM: "/dev/null",
      },
      cwd,
    });

    tui.start();
    tui.requestRender(true);
    done(result.status);

    // Return minimal component (immediately disposed since done() was called)
    return { render: () => [], invalidate: () => {} };
  };
}

export default function (pi: ExtensionAPI) {
  // Ctrl+Q — unstaged diff
  pi.registerShortcut("ctrl+q", {
    description: "Open critique diff viewer (unstaged)",
    handler: async (ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("Critique requires TUI mode", "error");
        return;
      }
      await ctx.ui.custom<number | null>(launchCritique(ctx.cwd));
    },
  });

  // Ctrl+R — staged diff
  pi.registerShortcut("ctrl+r", {
    description: "Open critique diff viewer (staged)",
    handler: async (ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("Critique requires TUI mode", "error");
        return;
      }
      await ctx.ui.custom<number | null>(launchCritique(ctx.cwd, ["--staged"]));
    },
  });

  // /critique — run with custom args
  pi.registerCommand("critique", {
    description: "Open critique diff viewer. Args passed through (e.g. --staged, --web, main HEAD)",
    handler: async (args: string, ctx: ExtensionCommandContext) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("Critique requires TUI mode", "error");
        return;
      }
      const parsedArgs = args.trim() ? args.trim().split(/\s+/) : [];
      await ctx.ui.custom<number | null>(launchCritique(ctx.cwd, parsedArgs));
    },
  });

  // /critique-review — AI-powered review
  pi.registerCommand("critique-review", {
    description: "Run critique AI review. Args passed through (e.g. --staged, --agent claude)",
    handler: async (args: string, ctx: ExtensionCommandContext) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("Critique requires TUI mode", "error");
        return;
      }
      const parsedArgs = ["review", ...(args.trim() ? args.trim().split(/\s+/) : [])];
      await ctx.ui.custom<number | null>(launchCritique(ctx.cwd, parsedArgs));
    },
  });
}
