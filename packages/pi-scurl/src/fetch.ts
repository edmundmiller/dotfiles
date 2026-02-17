/**
 * Core fetch logic: HTTP fetch → mdream HTML-to-markdown conversion.
 */

import { htmlToMarkdown } from "mdream";
import { withMinimalPreset } from "mdream/preset/minimal";
import { scanUrl, scanHeaders, type SecretScanResult } from "./secrets";
import {
  analyzeInjection,
  wrapInjection,
  type InjectionAction,
  type InjectionAnalysis,
} from "./injection";

export interface FetchOptions {
  /** Custom headers */
  headers?: Record<string, string>;
  /** Request timeout in ms (default: 30000) */
  timeout?: number;
  /** Use minimal preset for LLM-optimized output (default: true) */
  minimal?: boolean;
  /** Return raw HTML without markdown conversion */
  raw?: boolean;
  /** Enable prompt injection detection (default: true) */
  detectInjection?: boolean;
  /** Injection detection threshold 0.0–1.0 (default: 0.3) */
  injectionThreshold?: number;
  /** Action on injection: warn, redact, tag, none (default: warn) */
  injectionAction?: InjectionAction;
  /** Enable secret scanning on outgoing URLs (default: true) */
  scanSecrets?: boolean;
  /** AbortSignal for cancellation */
  signal?: AbortSignal;
}

export interface FetchResult {
  /** Markdown (or raw HTML) content */
  content: string;
  /** HTTP status code */
  status: number;
  /** Content type from response */
  contentType: string;
  /** Original URL */
  url: string;
  /** Whether content was converted to markdown */
  converted: boolean;
  /** Byte size of original HTML */
  originalSize: number;
  /** Byte size of converted output */
  outputSize: number;
  /** Injection analysis (if detection enabled) */
  injection?: InjectionAnalysis;
  /** Error message if something went wrong */
  error?: string;
}

/** Content types that should be converted to markdown */
function isHtmlLike(contentType: string): boolean {
  const ct = contentType.toLowerCase();
  return ct.includes("text/html") || ct.includes("application/xhtml");
}

/** Extract origin (scheme + host) from URL for mdream link resolution */
function getOrigin(url: string): string {
  try {
    const u = new URL(url);
    return u.origin;
  } catch {
    return "";
  }
}

/**
 * Fetch a URL, convert HTML to markdown via mdream, scan for secrets & injections.
 */
export async function secureFetch(url: string, options: FetchOptions = {}): Promise<FetchResult> {
  const {
    headers = {},
    timeout = 30_000,
    minimal = true,
    raw = false,
    detectInjection = true,
    injectionThreshold = 0.3,
    injectionAction = "warn",
    scanSecrets = true,
    signal,
  } = options;

  // --- Secret scanning on outgoing request ---
  if (scanSecrets) {
    const urlScan = scanUrl(url);
    if (urlScan.found) {
      return {
        content: "",
        status: 0,
        contentType: "",
        url,
        converted: false,
        originalSize: 0,
        outputSize: 0,
        error: `BLOCKED: ${urlScan.pattern!.name} detected in ${urlScan.location}. Remove the secret before fetching.`,
      };
    }
    const headerScan = scanHeaders(headers);
    if (headerScan.found) {
      return {
        content: "",
        status: 0,
        contentType: "",
        url,
        converted: false,
        originalSize: 0,
        outputSize: 0,
        error: `BLOCKED: ${headerScan.pattern!.name} detected in ${headerScan.location}. Remove the secret before fetching.`,
      };
    }
  }

  // --- HTTP fetch ---
  let response: Response;
  try {
    const controller = new AbortController();
    const combinedSignal = signal
      ? AbortSignal.any([signal, controller.signal])
      : controller.signal;

    const timer = setTimeout(() => controller.abort(), timeout);

    response = await fetch(url, {
      headers: {
        "User-Agent": "pi-scurl/0.1",
        Accept: "text/html,application/xhtml+xml,text/plain,application/json,*/*",
        ...headers,
      },
      signal: combinedSignal,
      redirect: "follow",
    });

    clearTimeout(timer);
  } catch (err: any) {
    return {
      content: "",
      status: 0,
      contentType: "",
      url,
      converted: false,
      originalSize: 0,
      outputSize: 0,
      error:
        err.name === "AbortError"
          ? "Request timed out or was cancelled"
          : `Fetch error: ${err.message}`,
    };
  }

  const contentType = response.headers.get("content-type") ?? "";
  const body = await response.text();
  const originalSize = new TextEncoder().encode(body).length;

  // --- Non-HTML: return as-is ---
  if (!isHtmlLike(contentType) || raw) {
    let content = body;
    let injection: InjectionAnalysis | undefined;

    if (detectInjection && !raw) {
      injection = analyzeInjection(body, injectionThreshold);
      if (injection.flagged) {
        content = wrapInjection(body, injection, injectionAction);
      }
    }

    return {
      content,
      status: response.status,
      contentType,
      url,
      converted: false,
      originalSize,
      outputSize: new TextEncoder().encode(content).length,
      injection,
    };
  }

  // --- HTML → Markdown via mdream ---
  let markdown: string;
  try {
    const origin = getOrigin(url);
    if (minimal) {
      markdown = htmlToMarkdown(body, withMinimalPreset({ origin }));
    } else {
      markdown = htmlToMarkdown(body, { origin });
    }
  } catch (err: any) {
    return {
      content: body,
      status: response.status,
      contentType,
      url,
      converted: false,
      originalSize,
      outputSize: originalSize,
      error: `Markdown conversion failed: ${err.message}`,
    };
  }

  // --- Injection detection on converted markdown ---
  let injection: InjectionAnalysis | undefined;
  let content = markdown;
  if (detectInjection) {
    injection = analyzeInjection(markdown, injectionThreshold);
    if (injection.flagged) {
      content = wrapInjection(markdown, injection, injectionAction);
    }
  }

  const outputSize = new TextEncoder().encode(content).length;

  return {
    content,
    status: response.status,
    contentType,
    url,
    converted: true,
    originalSize,
    outputSize,
    injection,
  };
}
