import { createRequire } from "node:module";
import path from "node:path";
import type { ImageContent } from "./content.ts";
import {
  createImagePlaceholder,
  isClipboardTempFile,
  normalizePastedPath,
  removeImagePlaceholders,
  resolveMaybeRelativePath,
  sortByPlaceholderNumber,
} from "./path-utils.ts";

export type PendingSubmission = {
  matchText: string;
  transformedText: string;
  images: ImageContent[];
};

export type DraftAttachment = {
  placeholder: string;
  image: ImageContent;
  label: string;
  originalPath: string;
};

export type EditorHooks = {
  publishDraft: (attachments: DraftAttachment[]) => void;
  queuePendingSubmission: (submission: PendingSubmission) => void;
  sendImagesOnly: (images: ImageContent[]) => void;
};

export type EditorKeybindings = {
  matches(data: string, action: string): boolean;
};

export type EditorBase = {
  setText(text: string): void;
  getText(): string;
  insertTextAtCursor(text: string): void;
  handleInput(data: string): void;
  getExpandedText?(): string;
  isShowingAutocomplete?(): boolean;
};

export type EditorBaseConstructor = new (...args: any[]) => EditorBase;

export type AttachmentEditorDeps = {
  BaseEditor: EditorBaseConstructor;
  getEditorKeybindings?: EditorKeybindings | (() => EditorKeybindings);
  resolveCwd: () => string;
  looksLikeImagePath: (filePath: string) => boolean;
  readImageContentFromPath: (filePath: string) => ImageContent | null;
  maybeResizeImage?: (image: ImageContent) => Promise<ImageContent>;
  unlinkFile?: (filePath: string) => void;
};

const BRACKETED_PASTE_START = "\u001b[200~";
const BRACKETED_PASTE_END = "\u001b[201~";

type SubmitKeyMatcher = (data: string) => boolean;

let cachedSubmitKeyMatcher: SubmitKeyMatcher | null | undefined;

function fallbackSubmitKeyMatcher(data: string): boolean {
  return data === "\r" || data === "\n" || data === "\x1bOM";
}

function resolveSubmitKeyMatcher(): SubmitKeyMatcher {
  if (cachedSubmitKeyMatcher !== undefined) {
    return cachedSubmitKeyMatcher ?? fallbackSubmitKeyMatcher;
  }

  try {
    const require = createRequire(import.meta.url);
    const mod = require("@mariozechner/pi-tui") as {
      Key?: { enter?: string };
      matchesKey?: (data: string, key: string) => boolean;
    };

    if (typeof mod.matchesKey === "function" && typeof mod.Key?.enter === "string") {
      cachedSubmitKeyMatcher = (data: string) => mod.matchesKey!(data, mod.Key!.enter!);
      return cachedSubmitKeyMatcher;
    }
  } catch {
    // Fallback below.
  }

  cachedSubmitKeyMatcher = null;
  return fallbackSubmitKeyMatcher;
}

function createFallbackEditorKeybindings(): EditorKeybindings {
  return {
    matches(data: string, action: string): boolean {
      return action === "tui.input.submit" && resolveSubmitKeyMatcher()(data);
    },
  };
}

function resolveEditorKeybindings(
  candidate: AttachmentEditorDeps["getEditorKeybindings"]
): EditorKeybindings {
  try {
    const resolved = typeof candidate === "function" ? candidate() : candidate;
    if (resolved && typeof resolved.matches === "function") {
      return resolved;
    }
  } catch {
    // Fall back below.
  }

  return createFallbackEditorKeybindings();
}

function extractBracketedPaste(data: string): string | null {
  if (!data.startsWith(BRACKETED_PASTE_START) || !data.endsWith(BRACKETED_PASTE_END)) {
    return null;
  }
  return data.slice(BRACKETED_PASTE_START.length, -BRACKETED_PASTE_END.length);
}

export function createImageAttachmentEditor(deps: AttachmentEditorDeps) {
  const BaseEditor = deps.BaseEditor;

  return class ImageAttachmentEditor extends BaseEditor {
    private attachments: DraftAttachment[] = [];
    private hooks: EditorHooks;

    constructor(...args: any[]) {
      const hooks = args.pop() as EditorHooks;
      super(...args);
      this.hooks = hooks;
    }

    override setText(text: string): void {
      super.setText(text);
      this.syncAttachments();
      this.publishDraft();
    }

    override insertTextAtCursor(text: string): void {
      if (this.tryAttachPastedPath(text)) {
        return;
      }
      super.insertTextAtCursor(text);
      this.syncAttachments();
      this.publishDraft();
    }

    override handleInput(data: string): void {
      const bracketedPaste = extractBracketedPaste(data);
      if (bracketedPaste !== null && this.tryAttachPastedPath(bracketedPaste)) {
        return;
      }

      const editorKeybindings = this.getEditorKeybindings();
      const isSubmit =
        editorKeybindings.matches(data, "tui.input.submit") &&
        !(this.isShowingAutocomplete?.() ?? false);
      if (isSubmit && this.attachments.length > 0) {
        const fullText = (this.getExpandedText?.() ?? this.getText()).trim();
        const usedAttachments = sortByPlaceholderNumber(
          this.attachments.filter((attachment) => fullText.includes(attachment.placeholder))
        );

        if (
          usedAttachments.length > 0 &&
          !fullText.startsWith("/") &&
          !fullText.trimStart().startsWith("!")
        ) {
          const transformedText = removeImagePlaceholders(fullText);
          const images = usedAttachments.map((attachment) => attachment.image);

          if (!transformedText) {
            this.clearDraft();
            this.hooks.sendImagesOnly(images);
            return;
          }

          this.hooks.queuePendingSubmission({
            matchText: fullText,
            transformedText,
            images,
          });
        }
      }

      const beforeText = this.getText();
      super.handleInput(data);
      if (this.getText() !== beforeText) {
        this.syncAttachments();
        this.publishDraft();
      }
    }

    private clearDraft(): void {
      this.attachments = [];
      super.setText("");
      this.publishDraft();
    }

    private tryAttachPastedPath(rawText: string): boolean {
      const normalized = normalizePastedPath(rawText);
      if (!normalized) {
        return false;
      }

      const resolvedPath = resolveMaybeRelativePath(normalized, deps.resolveCwd());
      if (!deps.looksLikeImagePath(resolvedPath)) {
        return false;
      }

      const image = deps.readImageContentFromPath(resolvedPath);
      if (!image) {
        return false;
      }

      const placeholder = createImagePlaceholder(this.nextPlaceholderNumber());
      const attachment: DraftAttachment = {
        placeholder,
        image,
        label: path.basename(resolvedPath),
        originalPath: resolvedPath,
      };

      this.attachments.push(attachment);
      super.insertTextAtCursor(`${placeholder} `);
      this.publishDraft();

      if (deps.maybeResizeImage) {
        void deps
          .maybeResizeImage(image)
          .then((resized) => {
            attachment.image = resized;
          })
          .catch(() => {
            // Keep original image if resize fails.
          });
      }

      if (isClipboardTempFile(resolvedPath)) {
        try {
          deps.unlinkFile?.(resolvedPath);
        } catch {
          // Best effort cleanup only.
        }
      }

      return true;
    }

    private nextPlaceholderNumber(): number {
      const maxNumber = this.attachments.reduce((highest, attachment) => {
        const match = attachment.placeholder.match(/\[Image #(\d+)\]/);
        const current = match ? Number.parseInt(match[1] ?? "0", 10) : 0;
        return Math.max(highest, current);
      }, 0);
      return maxNumber + 1;
    }

    private syncAttachments(): void {
      const text = this.getText();
      this.attachments = this.attachments.filter((attachment) =>
        text.includes(attachment.placeholder)
      );
    }

    private getEditorKeybindings(): EditorKeybindings {
      return resolveEditorKeybindings(deps.getEditorKeybindings);
    }

    private publishDraft(): void {
      this.hooks.publishDraft(this.attachments);
    }
  };
}
