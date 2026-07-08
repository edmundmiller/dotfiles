/**
 * xurl Extension — resolve local and agent URIs from Pi
 *
 * Wraps Xuanwo/xurl for agent thread URIs and handles local Herdr/Hunk resources.
 *
 * Tool: xurl — resolve and read URI content
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

type XurlParams = {
  uri: string;
  raw?: boolean;
  list?: boolean;
};

type ResolverCommand = {
  command: string;
  args: string[];
  label: string;
};

type ResolverResult = {
  content: Array<{ type: "text"; text: string }>;
  details: Record<string, unknown>;
  isError?: boolean;
};

const TRUTHY: Record<string, true> = {
  "": true,
  "1": true,
  true: true,
  yes: true,
  on: true,
};

function boolParam(params: URLSearchParams, name: string): boolean {
  const value = params.get(name);
  return value !== null && TRUTHY[value.toLowerCase()] === true;
}

function positiveIntParam(params: URLSearchParams, name: string): string | undefined {
  const value = params.get(name);
  if (!value) return undefined;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0)
    throw new Error(`${name} must be a positive integer`);
  return String(parsed);
}

function pathId(url: URL, label: string): string {
  const id = decodeURIComponent(url.pathname.replace(/^\/+/, ""));
  if (!id) throw new Error(`${label} id is required`);
  return id;
}

function buildHerdrCommand(url: URL): ResolverCommand {
  switch (url.hostname) {
    case "snapshot":
      return { command: "herdr", args: ["api", "snapshot", "--json"], label: "herdr" };
    case "pane": {
      const args = [
        "pane",
        "read",
        pathId(url, "pane"),
        "--source",
        url.searchParams.get("source") ?? "recent",
      ];
      const lines = positiveIntParam(url.searchParams, "lines");
      if (lines) args.push("--lines", lines);
      if (boolParam(url.searchParams, "ansi")) args.push("--ansi");
      return { command: "herdr", args, label: "herdr" };
    }
    default:
      throw new Error(`unsupported herdr URI: ${url.href}`);
  }
}

function buildHunkCommand(url: URL, cwd: string): ResolverCommand {
  const repo = url.searchParams.get("repo") ?? cwd;
  switch (url.hostname) {
    case "review": {
      const args = ["session", "review", "--repo", repo];
      if (boolParam(url.searchParams, "includePatch")) args.push("--include-patch");
      if (boolParam(url.searchParams, "includeNotes")) args.push("--include-notes");
      return { command: "hunk", args, label: "hunk" };
    }
    case "comments": {
      const args = ["session", "comment", "list", "--repo", repo];
      const type = url.searchParams.get("type");
      if (type) args.push("--type", type);
      return { command: "hunk", args, label: "hunk" };
    }
    default:
      throw new Error(`unsupported hunk URI: ${url.href}`);
  }
}

function buildCommand(params: XurlParams, cwd = process.cwd()): ResolverCommand {
  if (params.uri.startsWith("herdr://")) return buildHerdrCommand(new URL(params.uri));
  if (params.uri.startsWith("hunk://")) return buildHunkCommand(new URL(params.uri), cwd);

  const args = [...XURL_ARGS, params.uri];
  if (params.raw) args.push("--raw");
  if (params.list) args.push("--list");
  return { command: XURL_CMD, args, label: "xurl" };
}

function truncateOutput(output: string): { text: string; truncated: boolean } {
  const truncation = truncateHead(output, {
    maxLines: DEFAULT_MAX_LINES,
    maxBytes: DEFAULT_MAX_BYTES,
  });

  let text = truncation.content;
  if (truncation.truncated) {
    text += `\n\n[Output truncated: ${truncation.outputLines} of ${truncation.totalLines} lines`;
    text += ` (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)})]`;
  }

  return { text, truncated: truncation.truncated };
}

async function resolveUri(
  pi: ExtensionAPI,
  params: XurlParams,
  signal?: AbortSignal,
  cwd?: string
): Promise<ResolverResult> {
  let resolver: ResolverCommand;
  try {
    resolver = buildCommand(params, cwd);
  } catch (error) {
    const text = error instanceof Error ? error.message : String(error);
    return {
      content: [{ type: "text", text }],
      details: { uri: params.uri, error: text },
      isError: true,
    };
  }

  const result = await pi.exec(resolver.command, resolver.args, {
    signal,
    timeout: 30_000,
  });

  if (result.code !== 0) {
    const stderr = result.stderr?.trim() || "unknown error";
    return {
      content: [
        { type: "text", text: `${resolver.label} failed (exit ${result.code}): ${stderr}` },
      ],
      details: {
        uri: params.uri,
        command: resolver.command,
        args: resolver.args,
        exitCode: result.code,
        error: stderr,
      },
      isError: true,
    };
  }

  const output = result.stdout ?? "";
  const truncation = truncateOutput(output);
  return {
    content: [{ type: "text", text: truncation.text }],
    details: {
      uri: params.uri,
      command: resolver.command,
      args: resolver.args,
      raw: params.raw ?? false,
      list: params.list ?? false,
      truncated: truncation.truncated,
    },
  };
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "xurl",
    label: "xurl",
    description: `Resolve and read URI content.

Supports local resources:
  herdr://snapshot
  herdr://pane/<pane-id>?source=recent-unwrapped&lines=80
  hunk://review?repo=/path/to/repo&includePatch=1&includeNotes=1
  hunk://comments?repo=/path/to/repo&type=user

Supports cross-agent thread URIs through xurl:
  agents://codex/<id>
  agents://claude/<id>
  pi://<id>

Use raw=true/list=true for xurl-backed agent thread URIs.`,
    parameters: Type.Object({
      uri: Type.String({
        description: "URI (e.g. herdr://snapshot, hunk://review?repo=/repo, agents://codex/<id>)",
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

    async execute(
      _toolCallId: string,
      params: XurlParams,
      signal?: AbortSignal,
      _onUpdate?: unknown,
      ctx?: { cwd?: string }
    ): Promise<ResolverResult> {
      return resolveUri(pi, params, signal, ctx?.cwd);
    },
  });

  pi.registerCommand("xurl", {
    description: "Resolve a URI (usage: /xurl <uri> [--raw] [--list])",
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

      const result = await resolveUri(pi, { uri, raw, list }, undefined, ctx.cwd);

      if (result.isError) {
        ctx.ui.notify(result.content[0]?.text ?? "xurl failed", "error");
        return;
      }

      const output = result.content[0]?.text.trim() ?? "";
      const lines = output.split("\n");
      if (lines.length <= 10) {
        ctx.ui.notify(output, "info");
      } else {
        ctx.ui.notify(`${lines.length} lines returned. Use the xurl tool for full output.`, "info");
      }
    },
  });
}
