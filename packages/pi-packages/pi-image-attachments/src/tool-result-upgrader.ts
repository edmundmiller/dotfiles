import type { ContentBlock, ImageContent, TextContent } from "./content.ts";
import {
  collectTextContent,
  extractSavedScreenshotPaths,
  hasInlineImageContent,
  isScreenshotToolResult,
  resolveMaybeRelativePath,
} from "./path-utils.ts";

export type ToolResultEventLike = {
  toolName: string;
  content: ContentBlock[];
  details?: unknown;
  isError: boolean;
};

export async function upgradeScreenshotToolResult(
  event: ToolResultEventLike,
  cwd: string,
  loadImageFromPath: (filePath: string) => Promise<ImageContent | null>
): Promise<{ content: ContentBlock[] } | undefined> {
  if (event.isError || !isScreenshotToolResult(event) || hasInlineImageContent(event.content)) {
    return undefined;
  }

  const text = collectTextContent(event.content);
  const savedPaths = extractSavedScreenshotPaths(text);
  if (savedPaths.length === 0) {
    return undefined;
  }

  for (const rawPath of savedPaths) {
    const resolvedPath = resolveMaybeRelativePath(rawPath, cwd);
    const image = await loadImageFromPath(resolvedPath);
    if (image) {
      return {
        content: [...event.content, image],
      };
    }
  }

  const hint: TextContent = {
    type: "text",
    text: "[image-attachments: screenshot was saved via filePath but the image file was not readable from Pi. If you need to inspect the screenshot agentically, retry the screenshot tool without filePath so the image is returned inline.]",
  };
  return {
    content: [...event.content, hint],
  };
}
