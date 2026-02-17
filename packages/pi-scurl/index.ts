/**
 * pi-scurl: Secure web fetch for pi
 *
 * Provides a `web_fetch` tool that:
 * - Fetches URLs and converts HTML to LLM-optimized markdown via mdream
 * - Scans outgoing requests for leaked secrets (API keys, tokens)
 * - Detects prompt injection in fetched content
 * - Truncates output to stay within context limits
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
  truncateHead,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  formatSize,
} from "@mariozechner/pi-coding-agent";
import { Type, type Static } from "@sinclair/typebox";
import { StringEnum } from "@mariozechner/pi-ai";
import { Text } from "@mariozechner/pi-tui";
import { secureFetch, type FetchResult } from "./src/fetch";
import type { InjectionAction } from "./src/injection";

const fetchToolParams = Type.Object({
  url: Type.String({ description: "URL to fetch" }),
  raw: Type.Optional(
    Type.Boolean({
      description: "Return raw response without HTML-to-markdown conversion (default: false)",
    })
  ),
  minimal: Type.Optional(
    Type.Boolean({
      description: "Use minimal preset for maximum token reduction (default: true)",
    })
  ),
  headers: Type.Optional(
    Type.Record(Type.String(), Type.String(), {
      description: "Custom request headers as key-value pairs",
    })
  ),
  timeout: Type.Optional(
    Type.Number({
      description: "Request timeout in milliseconds (default: 30000)",
    })
  ),
  injection_action: Type.Optional(
    StringEnum(["warn", "redact", "tag", "none"] as const, {
      description:
        "Action on prompt injection detection: warn (wrap in tags), redact (mask patterns), tag (untrusted wrapper only), none (disabled). Default: warn",
    })
  ),
});

type FetchToolInput = Static<typeof fetchToolParams>;

interface FetchToolDetails {
  url: string;
  status: number;
  converted: boolean;
  originalSize: number;
  outputSize: number;
  reduction: string;
  injectionFlagged: boolean;
  injectionScore?: number;
  error?: string;
}

function formatReduction(original: number, output: number): string {
  if (original === 0) return "0%";
  const pct = ((1 - output / original) * 100).toFixed(1);
  return `${pct}%`;
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "web_fetch",
    label: "Web Fetch",
    description: `Fetch a URL and return clean markdown content optimized for LLMs. Converts HTML pages to compact markdown via mdream (~50-99% size reduction). Includes secret scanning (blocks requests containing API keys/tokens) and prompt injection detection (warns about manipulative content). Use for reading web pages, documentation, articles, API responses. Output truncated to ${DEFAULT_MAX_LINES} lines / ${formatSize(DEFAULT_MAX_BYTES)}.`,
    parameters: fetchToolParams,

    async execute(toolCallId, params: FetchToolInput, signal, onUpdate) {
      const url = params.url.replace(/^@/, ""); // strip leading @ (model quirk)

      onUpdate?.({
        content: [{ type: "text", text: `Fetching ${url}...` }],
        details: {},
      });

      const result: FetchResult = await secureFetch(url, {
        raw: params.raw,
        minimal: params.minimal ?? true,
        headers: params.headers,
        timeout: params.timeout,
        injectionAction: (params.injection_action as InjectionAction) ?? "warn",
        signal: signal ?? undefined,
      });

      // Build details
      const details: FetchToolDetails = {
        url: result.url,
        status: result.status,
        converted: result.converted,
        originalSize: result.originalSize,
        outputSize: result.outputSize,
        reduction: formatReduction(result.originalSize, result.outputSize),
        injectionFlagged: result.injection?.flagged ?? false,
        injectionScore: result.injection?.score,
        error: result.error,
      };

      // Error
      if (result.error) {
        return {
          content: [{ type: "text", text: result.error }],
          isError: true,
          details,
        };
      }

      // Truncate
      const truncation = truncateHead(result.content, {
        maxLines: DEFAULT_MAX_LINES,
        maxBytes: DEFAULT_MAX_BYTES,
      });

      let text = truncation.content;
      if (truncation.truncated) {
        text += `\n\n[Output truncated: ${truncation.outputLines} of ${truncation.totalLines} lines (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)})]`;
      }

      // Header with metadata
      const header = [
        `URL: ${result.url}`,
        `Status: ${result.status}`,
        result.converted
          ? `Converted: HTML → Markdown (${formatSize(result.originalSize)} → ${formatSize(result.outputSize)}, ${details.reduction} reduction)`
          : `Raw: ${formatSize(result.originalSize)}`,
      ];

      if (result.injection?.flagged) {
        header.push(
          `⚠ Prompt injection detected (score: ${result.injection.score.toFixed(2)}, signals: ${result.injection.signals.join(", ")})`
        );
      }

      const output = header.join("\n") + "\n\n" + text;

      return {
        content: [{ type: "text", text: output }],
        details,
      };
    },

    renderCall(args: FetchToolInput, theme) {
      let text = theme.fg("toolTitle", theme.bold("web_fetch "));
      text += theme.fg("accent", args.url ?? "");
      if (args.raw) text += theme.fg("muted", " --raw");
      if (args.minimal === false) text += theme.fg("muted", " --full");
      return new Text(text, 0, 0);
    },

    renderResult(result, { expanded, isPartial }, theme) {
      if (isPartial) {
        const text = result.content?.[0]?.type === "text" ? result.content[0].text : "Fetching...";
        return new Text(theme.fg("warning", text), 0, 0);
      }

      const d = result.details as FetchToolDetails | undefined;
      if (!d) {
        const raw = result.content?.[0]?.type === "text" ? result.content[0].text : "";
        return new Text(raw, 0, 0);
      }

      if (d.error) {
        return new Text(theme.fg("error", `✗ ${d.error}`), 0, 0);
      }

      let text = "";
      if (d.converted) {
        text += theme.fg(
          "success",
          `✓ ${formatSize(d.originalSize)} → ${formatSize(d.outputSize)} (${d.reduction})`
        );
      } else {
        text += theme.fg("success", `✓ ${formatSize(d.outputSize)}`);
      }
      text += theme.fg("muted", ` ${d.status}`);

      if (d.injectionFlagged) {
        text += theme.fg("warning", ` ⚠ injection p=${d.injectionScore?.toFixed(2)}`);
      }

      if (expanded) {
        const content = result.content?.[0]?.type === "text" ? result.content[0].text : "";
        // Show first 20 lines of content
        const lines = content.split("\n").slice(0, 20);
        text += "\n" + theme.fg("dim", lines.join("\n"));
        if (content.split("\n").length > 20) {
          text += "\n" + theme.fg("dim", "...");
        }
      }

      return new Text(text, 0, 0);
    },
  });
}
