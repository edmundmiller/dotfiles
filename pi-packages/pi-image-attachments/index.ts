import { createRequire } from "node:module";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { CustomEditor, type ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { getKeybindings } from "@mariozechner/pi-tui";
import {
  loadImageContentFromPath,
  maybeResizeImage,
  readImageContentFromPath,
  type ImageResizer,
} from "./src/image-content.ts";
import { registerImageAttachmentsExtension } from "./src/extension-runtime.ts";
import { looksLikeImagePath } from "./src/path-utils.ts";

let cachedResizerPromise: Promise<ImageResizer | null> | undefined;

async function loadPiImageResizer(): Promise<ImageResizer | null> {
  if (cachedResizerPromise) {
    return cachedResizerPromise;
  }

  cachedResizerPromise = (async () => {
    try {
      const require = createRequire(import.meta.url);
      const piEntry = require.resolve("@mariozechner/pi-coding-agent");
      const distDir = path.dirname(piEntry);
      const moduleUrl = pathToFileURL(path.join(distDir, "utils", "image-resize.js")).href;
      const mod = (await import(moduleUrl)) as {
        resizeImage?: (image: {
          type: "image";
          data: string;
          mimeType: string;
        }) => Promise<{ data: string; mimeType: string }>;
      };
      if (!mod.resizeImage) {
        return null;
      }
      return async (image) => {
        const resized = await mod.resizeImage!(image);
        return {
          type: "image",
          data: resized.data,
          mimeType: resized.mimeType,
        };
      };
    } catch {
      return null;
    }
  })();

  return cachedResizerPromise;
}

export default function (pi: ExtensionAPI): void {
  registerImageAttachmentsExtension(pi, {
    BaseEditor: CustomEditor as any,
    getEditorKeybindings: getKeybindings,
    resolveCwd: () => process.cwd(),
    looksLikeImagePath,
    readImageContentFromPath,
    maybeResizeImage: async (image) => maybeResizeImage(image, await loadPiImageResizer()),
    loadImageContentFromPath: async (filePath) =>
      loadImageContentFromPath(filePath, await loadPiImageResizer()),
  });
}
