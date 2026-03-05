/**
 * Delta Diff Extension - Uses delta (https://github.com/dandavison/delta) to
 * colorize and highlight diffs shown for the edit tool.
 *
 * Overrides the built-in edit tool, delegates execution to the original
 * implementation, then pipes the diff through delta for rendering.
 *
 * Requires: delta installed and on PATH
 */

import type { ExtensionAPI, EditToolDetails } from "@mariozechner/pi-coding-agent";
import { createEditTool } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { execSync } from "node:child_process";
import { writeFileSync, unlinkSync, rmdirSync, mkdtempSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

/**
 * Convert pi's custom diff format to standard unified diff.
 *
 * Pi format:  `-  5 old line` / `+  5 new line` / `   6 context`
 * Standard:   `-old line`     / `+new line`      / ` context`
 */
function piDiffToUnified(piDiff: string, filePath?: string): string {
  const lines = piDiff.split("\n");
  const header = [
    `--- a/${filePath ?? "file"}`,
    `+++ b/${filePath ?? "file"}`,
    "@@ -1,1 +1,1 @@", // dummy hunk header so delta recognizes the format
  ];
  const body = lines.map((line) => {
    // Match pi's format: prefix(+/- /space) + padded line number + space + content
    const match = line.match(/^([+-\s])(\s*\d*)\s(.*)$/);
    if (!match) return line;
    const prefix = match[1];
    const content = match[3];
    // Reconstruct as standard diff line
    if (prefix === "+") return `+${content}`;
    if (prefix === "-") return `-${content}`;
    return ` ${content}`;
  });

  return [...header, ...body].join("\n");
}

/**
 * Pipe a unified diff through delta --color-only and return ANSI output.
 * Falls back to the raw diff if delta fails.
 */
function runDelta(unifiedDiff: string): string | null {
  const tmp = mkdtempSync(join(tmpdir(), "pi-delta-"));
  const tmpFile = join(tmp, "diff.patch");
  try {
    writeFileSync(tmpFile, unifiedDiff, "utf-8");
    const result = execSync(`delta --no-gitconfig --color-only < "${tmpFile}"`, {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
      timeout: 5000,
    });
    // Strip the header lines (--- a/file, +++ b/file, @@ ...) from delta output
    // since pi already shows the file path in the tool call header
    const outputLines = result.split("\n");
    const bodyStart = outputLines.findIndex((l) =>
      l.replace(/\x1b\[[0-9;]*m/g, "").startsWith("@@")
    );
    if (bodyStart >= 0) {
      return outputLines.slice(bodyStart + 1).join("\n");
    }
    return result;
  } catch {
    return null;
  } finally {
    try {
      unlinkSync(tmpFile);
      rmdirSync(tmp);
    } catch {
      // ignore cleanup errors
    }
  }
}

export default function (pi: ExtensionAPI) {
  // Check delta is available
  let hasDelta = false;
  try {
    execSync("delta --version", { stdio: "pipe" });
    hasDelta = true;
  } catch {
    // delta not found
  }

  if (!hasDelta) {
    pi.on("session_start", async (_event, ctx) => {
      ctx.ui.notify("delta-diff: 'delta' not found on PATH, extension disabled", "warning");
    });
    return;
  }

  const builtinEdit = createEditTool(process.cwd());

  pi.registerTool({
    name: "edit",
    label: "edit",
    description: builtinEdit.description,
    parameters: builtinEdit.parameters,

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      // Delegate to the built-in edit tool (but with correct cwd)
      const tool = createEditTool(ctx.cwd);
      const result = await tool.execute(toolCallId, params, signal, onUpdate);
      const details = result.details as EditToolDetails | undefined;

      if (details?.diff) {
        const unified = piDiffToUnified(details.diff, params.path);
        const deltaOutput = runDelta(unified);
        if (deltaOutput) {
          (result.details as any).__deltaOutput = deltaOutput;
          (result.details as any).__piDiff = details.diff;
        }
      }

      return result;
    },

    renderCall(args: any, theme: any) {
      const path = args?.path ?? "";
      let text = theme.fg("toolTitle", theme.bold("edit")) + " ";
      text += path ? theme.fg("accent", path) : theme.fg("toolOutput", "...");
      return new Text(text, 0, 0);
    },

    renderResult(result: any, options: any, theme: any) {
      const details = result.details;

      if (result.isError || !details) {
        const errorText = result.content?.map((c: any) => c.text).join("") ?? "Unknown error";
        return new Text(theme.fg("error", errorText), 0, 0);
      }

      const deltaOutput = details.__deltaOutput;
      const piDiff = details.__piDiff ?? details.diff;

      if (deltaOutput) {
        return new Text(deltaOutput, 0, 0);
      }

      // Fallback: no delta output, show raw diff
      if (piDiff) {
        return new Text(piDiff, 0, 0);
      }

      const text = result.content?.map((c: any) => c.text).join("") ?? "";
      return new Text(theme.fg("success", text), 0, 0);
    },
  });
}
