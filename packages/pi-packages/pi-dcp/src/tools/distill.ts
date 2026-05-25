/**
 * dcp_distill tool — replace verbose tool outputs with concise summaries
 *
 * Unlike prune (which removes entirely), distill preserves key information
 * in a compressed form. Good for outputs you might still reference.
 */

import { Type } from "@sinclair/typebox";
import type { ToolCacheState } from "../tool-cache";
import { getLogger } from "../logger";

export const distillToolName = "dcp_distill";

export const distillToolDescription =
  "Replace tool outputs with concise summaries. " +
  "Use when the output contains useful information but is too verbose. " +
  "Provide a distillation for each tool ID that captures the key facts.";

export const distillToolParameters = Type.Object({
  targets: Type.Array(
    Type.Object({
      id: Type.String({ description: "Numeric ID from <prunable-tools> list" }),
      distillation: Type.String({
        description: "Concise summary to replace the full output",
      }),
    }),
    { description: "Tool outputs to distill with their replacement summaries" }
  ),
});

export function executeDistill(
  state: ToolCacheState,
  params: { targets: { id: string; distillation: string }[] },
  protectedTools: string[] = []
): { distilled: number; skipped: string[]; message: string } {
  const logger = getLogger();
  let distilled = 0;
  const skipped: string[] = [];

  for (const target of params.targets) {
    const numericId = parseInt(target.id, 10);
    if (isNaN(numericId) || numericId < 0 || numericId >= state.idList.length) {
      skipped.push(`${target.id} (invalid ID)`);
      continue;
    }

    const callId = state.idList[numericId];
    if (state.prunedIds.has(callId)) {
      skipped.push(`${target.id} (already pruned)`);
      continue;
    }

    const entry = state.cache.get(callId);
    if (!entry) {
      skipped.push(`${target.id} (not found)`);
      continue;
    }

    if (protectedTools.includes(entry.toolName)) {
      skipped.push(`${target.id} (protected: ${entry.toolName})`);
      continue;
    }

    // Mark as pruned and store distillation
    state.prunedIds.add(callId);
    state.distillations.set(callId, target.distillation);
    distilled++;
    logger.info(
      `Distilled tool call ${numericId}: ${entry.toolName}(${entry.paramKey}) → ${target.distillation.length} chars`
    );
  }

  const parts: string[] = [`Distilled ${distilled} tool output(s).`];
  if (skipped.length > 0) {
    parts.push(`Skipped: ${skipped.join(", ")}`);
  }

  return { distilled, skipped, message: parts.join(" ") };
}
