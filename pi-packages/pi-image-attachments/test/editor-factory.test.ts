import { afterEach, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createImageAttachmentEditor } from "../src/editor-factory.ts";
import type {
  AttachmentEditorDeps,
  DraftAttachment,
  PendingSubmission,
} from "../src/editor-factory.ts";
import type { ImageContent } from "../src/content.ts";

class FakeBaseEditor {
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

  handleInput(_data: string): void {
    // No-op: the attachment editor under test owns the interesting behavior.
  }
}

function createTempImagePath(): { dir: string; imagePath: string } {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-image-attachments-"));
  const imagePath = path.join(dir, "shot.png");
  fs.writeFileSync(imagePath, "");
  return { dir, imagePath };
}

function buildDeps(options: {
  imagePath: string;
  getEditorKeybindings?: AttachmentEditorDeps["getEditorKeybindings"];
}): AttachmentEditorDeps {
  const image: ImageContent = {
    type: "image",
    data: "image-data",
    mimeType: "image/png",
  };

  return {
    BaseEditor: FakeBaseEditor as unknown as AttachmentEditorDeps["BaseEditor"],
    getEditorKeybindings: options.getEditorKeybindings,
    resolveCwd: () => path.dirname(options.imagePath),
    looksLikeImagePath: (filePath: string) => filePath === options.imagePath,
    readImageContentFromPath: (filePath: string) => (filePath === options.imagePath ? image : null),
  };
}

function createHarness(options: {
  imagePath: string;
  getEditorKeybindings?: AttachmentEditorDeps["getEditorKeybindings"];
}) {
  const publishedDrafts: DraftAttachment[][] = [];
  let pendingSubmission: PendingSubmission | undefined;
  let sentImages: ImageContent[] | undefined;

  const EditorClass = createImageAttachmentEditor(buildDeps(options));
  const editor = new EditorClass({
    publishDraft: (attachments) => {
      publishedDrafts.push([...attachments]);
    },
    queuePendingSubmission: (submission) => {
      pendingSubmission = submission;
    },
    sendImagesOnly: (images) => {
      sentImages = images;
    },
  });

  return {
    editor,
    publishedDrafts,
    get pendingSubmission() {
      return pendingSubmission;
    },
    get sentImages() {
      return sentImages;
    },
  };
}

let cleanupDirs: string[] = [];

afterEach(() => {
  for (const dir of cleanupDirs) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
  cleanupDirs = [];
});

test("falls back to enter detection when getEditorKeybindings is missing", () => {
  const { dir, imagePath } = createTempImagePath();
  cleanupDirs.push(dir);

  const harness = createHarness({ imagePath });

  harness.editor.insertTextAtCursor(imagePath);
  harness.editor.insertTextAtCursor("hello");

  expect(() => harness.editor.handleInput("\r")).not.toThrow();
  expect(harness.pendingSubmission?.matchText).toBe("[Image #1] hello");
  expect(harness.pendingSubmission?.transformedText).toBe("hello");
  expect(harness.pendingSubmission?.images).toHaveLength(1);
  expect(harness.sentImages).toBeUndefined();
});

test("accepts a pre-resolved keybinding object", () => {
  const { dir, imagePath } = createTempImagePath();
  cleanupDirs.push(dir);

  const harness = createHarness({
    imagePath,
    getEditorKeybindings: {
      matches(data, action) {
        return action === "tui.input.submit" && data === "\r";
      },
    },
  });

  harness.editor.insertTextAtCursor(imagePath);
  harness.editor.insertTextAtCursor("hello");
  harness.editor.handleInput("\r");

  expect(harness.pendingSubmission?.transformedText).toBe("hello");
  expect(harness.pendingSubmission?.images).toHaveLength(1);
});

test("falls back when keybinding matcher throws during typing", () => {
  const { dir, imagePath } = createTempImagePath();
  cleanupDirs.push(dir);

  const harness = createHarness({
    imagePath,
    getEditorKeybindings: {
      matches() {
        throw new Error("incompatible keybinding matcher");
      },
    },
  });

  harness.editor.insertTextAtCursor(imagePath);
  harness.editor.insertTextAtCursor("hello");

  expect(() => harness.editor.handleInput("\r")).not.toThrow();
  expect(harness.pendingSubmission?.transformedText).toBe("hello");
  expect(harness.pendingSubmission?.images).toHaveLength(1);
});

test("the extension module imports without eagerly loading Pi runtime packages", async () => {
  const mod = await import("../index.ts");
  expect(typeof mod.default).toBe("function");
});

test("the extension registers with a minimal Pi stub when runtime packages are absent", async () => {
  const events: string[] = [];
  const pi = {
    on(event: string, _handler: (...args: any[]) => any) {
      events.push(event);
    },
    sendUserMessage() {
      // No-op for this smoke test.
    },
  };

  const mod = await import("../index.ts");
  await expect(mod.default(pi as any)).resolves.toBeUndefined();
  expect(events).toContain("session_start");
  expect(events).toContain("input");
});
