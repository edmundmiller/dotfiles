import type { ContentBlock, ImageContent } from "./content.ts";
import {
  createImageAttachmentEditor,
  type AttachmentEditorDeps,
  type DraftAttachment,
  type PendingSubmission,
} from "./editor-factory.ts";
import { PREFER_INLINE_SCREENSHOT_PROMPT } from "./prompt.ts";
import { upgradeScreenshotToolResult } from "./tool-result-upgrader.ts";

export type PiLike = {
  on(event: string, handler: (event: any, ctx: ExtensionContextLike) => any): void;
  sendUserMessage(
    content: string | ContentBlock[],
    options?: { deliverAs?: "steer" | "followUp" }
  ): void;
};

export type ExtensionContextLike = {
  cwd: string;
  isIdle(): boolean;
  ui: {
    setWidget(
      key: string,
      content: string[] | undefined,
      options?: { placement?: "aboveEditor" | "belowEditor" }
    ): void;
    setEditorComponent(factory: ((...args: any[]) => any) | undefined): void;
  };
};

export type ExtensionRuntimeDeps = AttachmentEditorDeps & {
  loadImageContentFromPath: (filePath: string) => Promise<ImageContent | null>;
};

const EXTENSION_WIDGET_KEY = "image-attachments";

export function registerImageAttachmentsExtension(pi: PiLike, deps: ExtensionRuntimeDeps): void {
  let currentDraftAttachments: DraftAttachment[] = [];
  let pendingSubmission: PendingSubmission | undefined;

  const refreshWidget = (ctx: ExtensionContextLike) => {
    if (currentDraftAttachments.length === 0) {
      ctx.ui.setWidget(EXTENSION_WIDGET_KEY, undefined);
      return;
    }

    const lines = [
      "Attached images:",
      ...currentDraftAttachments.map(
        (attachment) => `${attachment.placeholder} ${attachment.label}`
      ),
    ];
    ctx.ui.setWidget(EXTENSION_WIDGET_KEY, lines, { placement: "aboveEditor" });
  };

  const EditorClass = createImageAttachmentEditor(deps);

  const installEditor = (ctx: ExtensionContextLike) => {
    ctx.ui.setEditorComponent(
      (...args: any[]) =>
        new EditorClass(...args, {
          publishDraft: (attachments: DraftAttachment[]) => {
            currentDraftAttachments = [...attachments];
            refreshWidget(ctx);
          },
          queuePendingSubmission: (submission: PendingSubmission) => {
            pendingSubmission = submission;
          },
          sendImagesOnly: (images: ImageContent[]) => {
            currentDraftAttachments = [];
            pendingSubmission = undefined;
            refreshWidget(ctx);
            pi.sendUserMessage(images, ctx.isIdle() ? undefined : { deliverAs: "steer" });
          },
        })
    );
    refreshWidget(ctx);
  };

  const resetDraft = (ctx: ExtensionContextLike) => {
    currentDraftAttachments = [];
    pendingSubmission = undefined;
    ctx.ui.setWidget(EXTENSION_WIDGET_KEY, undefined);
  };

  pi.on("before_agent_start", () => {
    return {
      systemPrompt: PREFER_INLINE_SCREENSHOT_PROMPT,
    };
  });

  pi.on("session_start", async (_event, ctx) => {
    installEditor(ctx);
  });

  pi.on("session_switch", async (_event, ctx) => {
    resetDraft(ctx);
    installEditor(ctx);
  });

  pi.on("tool_result", async (event, ctx) => {
    return upgradeScreenshotToolResult(event, ctx.cwd, deps.loadImageContentFromPath);
  });

  pi.on("input", async (event, ctx) => {
    if (pendingSubmission && event.text === pendingSubmission.matchText) {
      const submission = pendingSubmission;
      const mergedImages = [...(event.images ?? []), ...submission.images];
      pendingSubmission = undefined;
      currentDraftAttachments = [];
      refreshWidget(ctx);
      return {
        action: "transform" as const,
        text: submission.transformedText,
        images: mergedImages,
      };
    }

    return { action: "continue" as const };
  });
}
