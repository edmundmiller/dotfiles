import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { ContentBlock, TextContent } from "./content.ts";

export const IMAGE_PLACEHOLDER_RE = /\[Image #(\d+)\]/g;
export const SINGLE_IMAGE_PLACEHOLDER_RE = /\[Image #(\d+)\]/;
const SCREENSHOT_SAVE_LINE_RE = /^Saved screenshot to\s+(.+)$/gim;

const IMAGE_MIME_BY_EXT: Record<string, string> = {
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  gif: "image/gif",
  webp: "image/webp",
};

export function stripOuterQuotes(value: string): string {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }
  return value;
}

export function normalizePastedPath(pasted: string): string | null {
  const trimmed = pasted.trim();
  if (!trimmed) {
    return null;
  }

  const unquoted = stripOuterQuotes(trimmed);

  try {
    const url = new URL(unquoted);
    if (url.protocol === "file:") {
      return fileURLToPath(url);
    }
  } catch {
    // Not a URL.
  }

  return unquoted.replace(/\\ /g, " ");
}

export function inferMimeType(filePath: string): string | null {
  const ext = path.extname(filePath).replace(/^\./, "").toLowerCase();
  return IMAGE_MIME_BY_EXT[ext] ?? null;
}

export function looksLikeImagePath(filePath: string): boolean {
  const mimeType = inferMimeType(filePath);
  return mimeType !== null && fs.existsSync(filePath) && fs.statSync(filePath).isFile();
}

export function isClipboardTempFile(filePath: string): boolean {
  return (
    path.dirname(filePath) === os.tmpdir() && path.basename(filePath).startsWith("pi-clipboard-")
  );
}

export function resolveMaybeRelativePath(filePath: string, cwd: string): string {
  return path.isAbsolute(filePath) ? filePath : path.resolve(cwd, filePath);
}

export function createImagePlaceholder(number: number): string {
  return `[Image #${number}]`;
}

export function removeImagePlaceholders(text: string): string {
  return text.replace(IMAGE_PLACEHOLDER_RE, " ").replace(/\s+/g, " ").trim();
}

export function sortByPlaceholderNumber<T extends { placeholder: string }>(items: T[]): T[] {
  return [...items].sort((left, right) => {
    const leftMatch = left.placeholder.match(SINGLE_IMAGE_PLACEHOLDER_RE);
    const rightMatch = right.placeholder.match(SINGLE_IMAGE_PLACEHOLDER_RE);
    const leftNum = leftMatch ? Number.parseInt(leftMatch[1] ?? "0", 10) : 0;
    const rightNum = rightMatch ? Number.parseInt(rightMatch[1] ?? "0", 10) : 0;
    return leftNum - rightNum;
  });
}

export function collectTextContent(content: ContentBlock[]): string {
  return content
    .filter((item): item is TextContent => item.type === "text")
    .map((item) => item.text)
    .join("\n");
}

export function hasInlineImageContent(content: ContentBlock[]): boolean {
  return content.some((item) => item.type === "image");
}

export function isScreenshotToolName(toolName: string): boolean {
  return (
    toolName === "take_screenshot" ||
    toolName === "chrome_devtools_take_screenshot" ||
    toolName.endsWith("_take_screenshot")
  );
}

export function isScreenshotToolResult(event: { toolName: string; details?: unknown }): boolean {
  if (isScreenshotToolName(event.toolName)) {
    return true;
  }
  if (!event.details || typeof event.details !== "object") {
    return false;
  }
  const maybeTool = (event.details as { tool?: unknown }).tool;
  return typeof maybeTool === "string" && isScreenshotToolName(maybeTool);
}

export function extractSavedScreenshotPaths(text: string): string[] {
  const paths: string[] = [];
  for (const match of text.matchAll(SCREENSHOT_SAVE_LINE_RE)) {
    const rawPath = match[1]?.trim();
    if (!rawPath) {
      continue;
    }
    paths.push(rawPath.replace(/\.$/, ""));
  }
  return paths;
}
