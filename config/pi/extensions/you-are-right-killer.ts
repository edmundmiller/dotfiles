/**
 * Subtle Reminders Extension
 *
 * Detects when the model uses reflexive agreement phrases like:
 * - "You are right"
 * - "You're right"
 * - "You are absolutely right"
 * - Similar variations
 *
 * When detected during streaming, immediately aborts and sends a reminder.
 * Only reminds once per 10 messages to avoid spam.
 */

import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

// Phrases that trigger the reminder (case-insensitive)
const REFLEXIVE_PHRASES = [
  /\byou are right\b/i,
  /\byou're right\b/i,
  /\byou're correct\b/i,
  /\byou are correct\b/i,
  /\byou're absolutely right\b/i,
  /\byou are absolutely right\b/i,
  /\bthat's right\b/i,
  /\bthats right\b/i,
  /\byou got it right\b/i,
  /\byou've got it right\b/i,
];

const REMINDER_MESSAGE = `STOP USING REFLEXIVE AGREEMENT PHRASES. STOP SAYING "YOU ARE RIGHT" to the user or similar.

Avoid reflexive agreement phrases like "you are right" or "absolutely correct."

Instead, engage thoughtfully: analyze the user's reasoning, identify potential improvements, 
or provide substantive confirmation when their approach is sound.

When the user presents a valid solution:

- Acknowledge the correctness with specific technical reasoning
- Consider edge cases, alternative approaches, or potential optimizations
- Build collaboratively rather than merely agreeing

When the user's approach has issues:
- Identify specific problems or gaps
- Suggest concrete improvements
- Explain the technical reasoning behind your analysis
`;

// Custom message type for tracking reminders
const REMINDER_CUSTOM_TYPE = "stop-reflexive-reminders";

// Track streaming state
let currentMessageBuffer = "";

function hasReflexivePhrase(text: string): boolean {
  return REFLEXIVE_PHRASES.some((pattern) => pattern.test(text));
}

export default function subtleRemindersExtension(pi: ExtensionAPI) {
  pi.on("message_update", async (event, ctx) => {
    const message = event.message as AgentMessage & { customType?: string };

    if (message.role !== "assistant" || message.customType === REMINDER_CUSTOM_TYPE) {
      return;
    }

    if (event.assistantMessageEvent.type === "text_delta") {
      const delta = event.assistantMessageEvent.delta;
      currentMessageBuffer += delta;

      if (hasReflexivePhrase(currentMessageBuffer)) {
        currentMessageBuffer = "";
        ctx.abort();

        const interruptionMessage = `I interrupted your response because you were about to use a reflexive agreement phrase ("you are right", etc.).

${REMINDER_MESSAGE}

Please provide a new response following these guidelines.`;

        setTimeout(() => {
          pi.sendMessage(
            {
              customType: REMINDER_CUSTOM_TYPE,
              content: interruptionMessage,
              display: false,
            },
            { triggerTurn: true }
          );
        }, 10);
      }
    }
  });

  pi.on("message_start", async () => {
    currentMessageBuffer = "";
  });
}
