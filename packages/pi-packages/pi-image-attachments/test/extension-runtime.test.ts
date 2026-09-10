import { expect, test } from "bun:test";
import { registerImageAttachmentsExtension, type PiLike } from "../src/extension-runtime.ts";

test("image attachments leave the system prompt untouched and retain attachment hooks", () => {
  const handlers = new Map<string, Parameters<PiLike["on"]>[1]>();
  registerImageAttachmentsExtension(
    {
      on: (event, handler) => {
        handlers.set(event, handler);
      },
      sendUserMessage: () => {},
    },
    {
      BaseEditor: class {
        setText(_text: string) {}
        getText() {
          return "";
        }
        insertTextAtCursor(_text: string) {}
        handleInput(_data: string) {}
      },
      resolveCwd: () => "/project",
      looksLikeImagePath: () => false,
      readImageContentFromPath: () => null,
      loadImageContentFromPath: async () => null,
    }
  );

  // No prompt hook means neither replacing nor appending model instructions.
  expect(handlers.has("before_agent_start")).toBe(false);
  expect([...handlers.keys()].sort()).toEqual([
    "input",
    "session_start",
    "session_switch",
    "tool_result",
  ]);
});
