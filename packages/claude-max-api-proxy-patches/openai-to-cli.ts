/**
 * Converts OpenAI chat request format to Claude CLI input
 * Patched: handle content arrays (OpenAI multipart format)
 */

import type { OpenAIChatRequest, OpenAIChatMessage } from "../types/openai.js";

export type ClaudeModel = "opus" | "sonnet" | "haiku";

export interface CliInput {
  prompt: string;
  model: ClaudeModel;
  sessionId?: string;
}

const MODEL_MAP: Record<string, ClaudeModel> = {
  "claude-opus-4": "opus",
  "claude-sonnet-4": "sonnet",
  "claude-haiku-4": "haiku",
  "claude-code-cli/claude-opus-4": "opus",
  "claude-code-cli/claude-sonnet-4": "sonnet",
  "claude-code-cli/claude-haiku-4": "haiku",
  opus: "opus",
  sonnet: "sonnet",
  haiku: "haiku",
};

/**
 * Normalize message content to a plain string.
 *
 * OpenAI spec allows content as either a string or an array of content
 * parts (e.g. [{type:"text",text:"hello"}, {type:"image_url",...}]).
 * Claude CLI expects a single string, so extract and join text parts.
 */
function normalizeContent(content: OpenAIChatMessage["content"]): string {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .filter((p: any) => p.type === "text" && p.text)
      .map((p: any) => p.text)
      .join("\n");
  }
  return String(content ?? "");
}

/**
 * Extract Claude model alias from request model string
 */
export function extractModel(model: string): ClaudeModel {
  if (MODEL_MAP[model]) return MODEL_MAP[model];
  const stripped = model.replace(/^claude-code-cli\//, "");
  if (MODEL_MAP[stripped]) return MODEL_MAP[stripped];
  return "opus";
}

/**
 * Convert OpenAI messages array to a single prompt string for Claude CLI
 *
 * Claude Code CLI in --print mode expects a single prompt, not a conversation.
 * We format the messages into a readable format that preserves context.
 */
export function messagesToPrompt(messages: OpenAIChatRequest["messages"]): string {
  const parts: string[] = [];

  for (const msg of messages) {
    const text = normalizeContent(msg.content);
    if (!text) continue;

    switch (msg.role) {
      case "system":
        parts.push(`<system>\n${text}\n</system>\n`);
        break;
      case "user":
        parts.push(text);
        break;
      case "assistant":
        parts.push(`<previous_response>\n${text}\n</previous_response>\n`);
        break;
    }
  }

  return parts.join("\n").trim();
}

/**
 * Convert OpenAI chat request to CLI input format
 */
export function openaiToCli(request: OpenAIChatRequest): CliInput {
  return {
    prompt: messagesToPrompt(request.messages),
    model: extractModel(request.model),
    sessionId: request.user,
  };
}
