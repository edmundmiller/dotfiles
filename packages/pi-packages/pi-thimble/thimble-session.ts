import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { Type } from "typebox";
import { Value } from "typebox/value";
import { thimbleJsonSchema, type ThimbleJson, type ThimbleRecord } from "./thimble-json.js";

type Branch = ReturnType<ExtensionContext["sessionManager"]["getBranch"]>;
type ThimbleSeenCall = { cwd: string; t: number } & (
  | { tool: "Read"; file: string; from: number | null; to: number | null; image: boolean }
  | { tool: "Bash"; command: string; out_lines: number }
);

/** Extract visible assistant text without thinking or tool calls. */
export function lastThimbleAnswer(branch: Branch): string {
  for (const entry of [...branch].reverse()) {
    if (entry.type !== "message" || entry.message.role !== "assistant") continue;
    const text = entry.message.content
      .filter((block) => block.type === "text")
      .map((block) => block.text)
      .join("\n");
    if (text.trim()) return text;
  }
  throw new Error("Thimble: this branch has no assistant answer yet");
}

/** Translate only successful, visible Pi reads into Thimble's coverage format. */
export function thimbleSeenCalls(branch: Branch, cwd: string) {
  const calls = new Map<string, { name: string; arguments: ThimbleRecord }>();
  const seen: ThimbleSeenCall[] = [];
  for (const entry of branch) {
    if (entry.type !== "message") continue;
    const message = entry.message;
    if (message.role === "assistant") {
      for (const block of message.content) {
        if (block.type === "toolCall") calls.set(block.id, block);
      }
    }
    if (message.role !== "toolResult" || message.isError) continue;
    const call = calls.get(message.toolCallId);
    if (!call) continue;
    const text = message.content
      .filter((block) => block.type === "text")
      .map((block) => block.text)
      .join("\n");
    const input = call.arguments;
    const base = { cwd, t: new Date(entry.timestamp).getTime() / 1000 };
    if (
      call.name === "read" &&
      Value.Check(
        Type.Object({
          path: Type.String(),
          offset: Type.Optional(Type.Integer({ minimum: 1 })),
        }),
        input
      )
    ) {
      const path = input.path.startsWith("~/")
        ? resolve(homedir(), input.path.slice(2))
        : resolve(cwd, input.path);
      const offset = input.offset ?? 1;
      // Pi appends continuation notices. They are not lines of the file.
      const visible = text.replace(/\n\n\[(?:Showing lines |\d+ more lines in file\.)[^]*$/, "");
      const tooLong = /^\[Line \d+ is .*exceeds .*limit\./.test(visible);
      const count = tooLong || !visible ? 0 : visible.replace(/\n$/, "").split("\n").length;
      seen.push({
        ...base,
        tool: "Read",
        file: path,
        from: count ? offset : null,
        to: count ? offset + count - 1 : null,
        image: message.content.some((block) => block.type === "image" && block.data.length > 0),
      });
    } else if (
      call.name === "bash" &&
      Value.Check(Type.Object({ command: Type.String() }), input)
    ) {
      // Bash keeps the tail of long output; treating it as the first lines
      // would claim that the model read a different part of the file.
      if (/\[(?:Showing (?:last |lines )|Output (?:truncated|exceeded))/.test(text)) continue;
      seen.push({
        ...base,
        tool: "Bash",
        command: input.command,
        out_lines: text.replace(/\n+$/, "").split("\n").length,
      });
    }
  }
  return seen;
}

/** Read extension records on the active branch, never on abandoned branches. */
export function thimbleBranchRecords(branch: Branch, kind: string): ThimbleJson[] {
  return branch.flatMap((entry) =>
    entry.type === "custom" && entry.customType === kind
      ? [Value.Parse(thimbleJsonSchema, entry.data)]
      : []
  );
}
