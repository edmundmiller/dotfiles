/**
 * Critique Extension — launch critique diff viewer from Pi
 *
 * Shortcuts:
 *   Ctrl+Shift+D — open critique TUI (unstaged diff)
 *   Ctrl+Shift+G — open critique TUI (staged diff)
 *
 * Commands:
 *   /critique [args]  — run critique with custom args
 *   /critique-review [args] — run critique review (AI-powered)
 */

import { spawnSync } from "node:child_process";
import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";

function launchCritique(args: string[] = []) {
  return (tui: any, _theme: any, _kb: any, done: (result: number | null) => void) => {
    tui.stop();
    process.stdout.write("\x1b[2J\x1b[H");

    const shell = process.env.SHELL || "/bin/sh";
    const command = ["critique", ...args].join(" ");
    const result = spawnSync(shell, ["-c", command], {
      stdio: "inherit",
      env: process.env,
    });

    tui.start();
    tui.requestRender(true);
    done(result.status);

    // Return minimal component (immediately disposed since done() was called)
    return { render: () => [], invalidate: () => {} };
  };
}

export default function (pi: ExtensionAPI) {
  // Ctrl+R — unstaged diff
  pi.registerShortcut("ctrl+shift+d", {
    description: "Open critique diff viewer",
    handler: async (ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("Critique requires TUI mode", "error");
        return;
      }
      await ctx.ui.custom<number | null>(launchCritique());
    },
  });

  // Ctrl+S — staged diff
  pi.registerShortcut("ctrl+shift+g", {
    description: "Open critique diff viewer (staged)",
    handler: async (ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("Critique requires TUI mode", "error");
        return;
      }
      await ctx.ui.custom<number | null>(launchCritique(["--staged"]));
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
      await ctx.ui.custom<number | null>(launchCritique(parsedArgs));
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
      await ctx.ui.custom<number | null>(launchCritique(parsedArgs));
    },
  });
}
