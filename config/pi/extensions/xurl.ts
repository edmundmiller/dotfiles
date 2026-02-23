/**
 * xurl Extension — resolve AI agent thread URIs from Pi
 *
 * Wraps Xuanwo/xurl (https://github.com/Xuanwo/xurl) as a Pi tool.
 * Resolves agents:// URIs for Amp, Codex, Claude, Gemini, Pi, and OpenCode threads.
 *
 * Tool: xurl — resolve and read agent thread content by URI
 * Command: /xurl <uri> [--raw] [--list]
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
  truncateHead,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  formatSize,
} from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

const XURL_CMD = "npx";
const XURL_ARGS = ["@xuanwo/xurl"];

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "xurl",
    label: "xurl",
    description: `Resolve and read AI agent thread content by URI.

Supports unified agents:// URIs and legacy provider URIs for: Amp, Codex, Claude, Gemini, Pi, OpenCode.

URI format: agents://<provider>/<thread_path>
Legacy: codex://<id>, claude://<id>, pi://<id>, amp://<id>, gemini://<id>, opencode://<id>

Examples:
  agents://codex/019c871c-b1f9-7f60-9c4f-87ed09f13592
  agents://claude/2823d1df-720a-4c31-ac55-ae8ba726721f
  agents://pi/12cb4c19-2774-4de4-a0d0-9fa32fbae29f

Use raw=true for JSON output. Use list=true to discover subagents/entries before drilling down.`,
    parameters: Type.Object({
      uri: Type.String({
        description: "Thread URI (e.g. agents://codex/<id>, agents://claude/<id>, pi://<id>)",
      }),
      raw: Type.Optional(
        Type.Boolean({
          description: "Output raw JSON instead of markdown (default: false)",
        })
      ),
      list: Type.Optional(
        Type.Boolean({
          description:
            "List subagents (Codex/Claude) or session entries (Pi) for discovery. Use with main thread URI only.",
        })
      ),
    }),

    async execute(toolCallId, params, signal) {
      const args = [...XURL_ARGS, params.uri];
      if (params.raw) args.push("--raw");
      if (params.list) args.push("--list");

      const result = await pi.exec(XURL_CMD, args, {
        signal,
        timeout: 30_000,
      });

      if (result.code !== 0) {
        const stderr = result.stderr?.trim() || "unknown error";
        return {
          content: [{ type: "text", text: `xurl failed (exit ${result.code}): ${stderr}` }],
          details: { exitCode: result.code, stderr },
          isError: true,
        };
      }

      const output = result.stdout;
      const truncation = truncateHead(output, {
        maxLines: DEFAULT_MAX_LINES,
        maxBytes: DEFAULT_MAX_BYTES,
      });

      let text = truncation.content;
      if (truncation.truncated) {
        text += `\n\n[Output truncated: ${truncation.outputLines} of ${truncation.totalLines} lines`;
        text += ` (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)})]`;
      }

      return {
        content: [{ type: "text", text }],
        details: {
          uri: params.uri,
          raw: params.raw ?? false,
          list: params.list ?? false,
          truncated: truncation.truncated,
        },
      };
    },
  });

  pi.registerCommand("xurl", {
    description: "Resolve an agent thread URI (usage: /xurl <uri> [--raw] [--list])",
    handler: async (argsStr, ctx) => {
      if (!argsStr?.trim()) {
        ctx.ui.notify("Usage: /xurl <uri> [--raw] [--list]", "warning");
        return;
      }

      const parts = argsStr.trim().split(/\s+/);
      const uri = parts.find((p) => !p.startsWith("--"));
      const raw = parts.includes("--raw");
      const list = parts.includes("--list");

      if (!uri) {
        ctx.ui.notify("No URI provided. Usage: /xurl <uri> [--raw] [--list]", "warning");
        return;
      }

      const args = [...XURL_ARGS, uri];
      if (raw) args.push("--raw");
      if (list) args.push("--list");

      const result = await pi.exec(XURL_CMD, args, { timeout: 30_000 });

      if (result.code !== 0) {
        ctx.ui.notify(`xurl failed: ${result.stderr?.trim() || "unknown error"}`, "error");
        return;
      }

      const output = result.stdout.trim();
      const lines = output.split("\n");
      if (lines.length <= 10) {
        ctx.ui.notify(output, "info");
      } else {
        ctx.ui.notify(`${lines.length} lines returned. Use the xurl tool for full output.`, "info");
      }
    },
  });
}
