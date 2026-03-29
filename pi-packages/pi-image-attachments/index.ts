import { createRequire } from "node:module";
import path from "node:path";
import { pathToFileURL } from "node:url";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
  loadImageContentFromPath,
  maybeResizeImage,
  readImageContentFromPath,
  type ImageResizer,
} from "./src/image-content.ts";
import { registerImageAttachmentsExtension } from "./src/extension-runtime.ts";
import type { EditorBaseConstructor, EditorKeybindings } from "./src/editor-factory.ts";
import { looksLikeImagePath } from "./src/path-utils.ts";

let cachedResizerPromise: Promise<ImageResizer | null> | undefined;
let cachedEditorKeybindings: EditorKeybindings | undefined;
let editorKeybindingsLoadPromise: Promise<void> | undefined;

function createFallbackCustomEditor(): EditorBaseConstructor {
  return class FallbackCustomEditor {
    private text = "";

    setText(text: string): void {
      this.text = text;
    }

    getText(): string {
      return this.text;
    }

    insertTextAtCursor(text: string): void {
      this.text += text;
    }

    handleInput(data: string): void {
      this.text += data;
    }

    getExpandedText(): string {
      return this.text;
    }

    isShowingAutocomplete(): boolean {
      return false;
    }
  };
}

function createFallbackEditorKeybindings(): EditorKeybindings {
  return {
    matches(data: string, action: string): boolean {
      return action === "tui.input.submit" && (data === "\r" || data === "\n" || data === "\x1bOM");
    },
  };
}

function loadEditorKeybindings(): Promise<void> {
  if (editorKeybindingsLoadPromise) {
    return editorKeybindingsLoadPromise;
  }

  editorKeybindingsLoadPromise = import("@mariozechner/pi-tui")
    .then((mod) => {
      const candidate = (mod as { getKeybindings?: unknown }).getKeybindings;
      const resolved = typeof candidate === "function" ? candidate() : candidate;

      if (resolved && typeof (resolved as EditorKeybindings).matches === "function") {
        cachedEditorKeybindings = resolved as EditorKeybindings;
      }
    })
    .catch(() => {
      // If pi-tui is unavailable, the extension keeps working with the fallback matcher.
    });

  return editorKeybindingsLoadPromise;
}

function getEditorKeybindings(): EditorKeybindings {
  if (!cachedEditorKeybindings) {
    void loadEditorKeybindings();
    return createFallbackEditorKeybindings();
  }

  return cachedEditorKeybindings;
}

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

async function loadCustomEditor(): Promise<EditorBaseConstructor> {
  try {
    const mod = await import("@mariozechner/pi-coding-agent");
    return mod.CustomEditor as EditorBaseConstructor;
  } catch {
    return createFallbackCustomEditor();
  }
}

export default async function (pi: ExtensionAPI): Promise<void> {
  const [CustomEditor] = await Promise.all([loadCustomEditor(), loadEditorKeybindings()]);

  registerImageAttachmentsExtension(pi, {
    BaseEditor: CustomEditor as any,
    getEditorKeybindings,
    resolveCwd: () => process.cwd(),
    looksLikeImagePath,
    readImageContentFromPath,
    maybeResizeImage: async (image) => maybeResizeImage(image, await loadPiImageResizer()),
    loadImageContentFromPath: async (filePath) =>
      loadImageContentFromPath(filePath, await loadPiImageResizer()),
  });
}
