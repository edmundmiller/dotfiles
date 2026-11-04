import { randomUUID } from "node:crypto";
import { instrument, type FlueObservationSubscriber } from "@flue/runtime";
import type { DrainContext, WideEvent } from "evlog";
import { z } from "zod";

const tokens = z.number().int().nonnegative();
const cost = z.number().nonnegative();
export const usageSchema = z.object({
  input: tokens,
  output: tokens,
  cacheRead: tokens,
  cacheWrite: tokens,
  totalTokens: tokens,
  cost: z.object({ input: cost, output: cost, cacheRead: cost, cacheWrite: cost, total: cost }),
});

// Explicit projection: neither tool output nor arbitrary provider/error fields enter the ledger.
export const recordSchema = z.object({
  schema: z.literal("flue.evlog.v1"),
  executionId: z.string().min(1),
  eventId: z.string().min(1),
  sequence: z.number().int().positive(),
  finalSequence: z.number().int().positive().optional(),
  event: z.enum([
    "telemetry_start",
    "telemetry_stop",
    "turn_request",
    "turn",
    "tool_start",
    "tool",
    "operation_start",
    "operation",
    "task_start",
    "task",
    "compaction",
    "run_end",
    "submission_settled",
  ]),
  timestamp: z.string(),
  contextId: z.string().optional(),
  agent: z.string().optional(),
  workflow: z.string().optional(),
  instanceId: z.string().optional(),
  submissionId: z.string().optional(),
  runId: z.string().optional(),
  session: z.string().optional(),
  parentSession: z.string().optional(),
  conversationId: z.string().optional(),
  taskId: z.string().optional(),
  operationId: z.string().optional(),
  turnId: z.string().optional(),
  toolCallId: z.string().optional(),
  tool: z.string().optional(),
  toolOrigin: z.enum(["model", "caller", "framework", "adapter"]).optional(),
  purpose: z.string().optional(),
  provider: z.string().optional(),
  model: z.string().optional(),
  requestedModel: z.string().optional(),
  responseId: z.string().optional(),
  finishReason: z.string().optional(),
  durationMs: z.number().nonnegative().optional(),
  failed: z.boolean().optional(),
  usage: usageSchema.optional(),
  usageStatus: z.enum(["reported", "missing", "invalid", "unknown"]).optional(),
  costStatus: z.enum(["estimated", "unknown"]).optional(),
  repository: z.string().optional(),
  commit: z.string().optional(),
  ciRun: z.string().optional(),
  ciAttempt: z.string().optional(),
  pr: z.string().optional(),
  target: z.string().optional(),
});
export type ObservationRecord = z.infer<typeof recordSchema>;

export interface FlueEvlogOptions {
  /** Must resolve after persistence, not just after enqueueing. */
  drain: (context: DrainContext) => void | Promise<void>;
  /** Must reject on dropped events or failed delivery, not just resolve when a queue empties. */
  flush?: () => Promise<void>;
  service: string;
  environment?: string;
  /** Only these non-content labels are exported. The adapter never reads environment variables. */
  metadata?: Pick<
    ObservationRecord,
    "repository" | "commit" | "ciRun" | "ciAttempt" | "pr" | "target"
  >;
}

export function installFlueEvlog(options: FlueEvlogOptions) {
  const executionId = randomUUID();
  const identity = {
    schema: "flue.evlog.v1" as const,
    executionId,
    service: options.service,
    environment: options.environment ?? "unknown",
    repository: options.metadata?.repository,
    commit: options.metadata?.commit,
    ciRun: options.metadata?.ciRun,
    ciAttempt: options.metadata?.ciAttempt,
    pr: options.metadata?.pr,
    target: options.metadata?.target,
  };
  let sequence = 0;
  const workflows = new Map<string, string>();
  let pending = Promise.resolve();
  let writeFailed = false;
  const drain = (context: DrainContext) => {
    // Serialize persistence and retain failures even if the runtime catches observer errors.
    pending = pending
      .then(() => options.drain(context))
      .catch(() => {
        writeFailed = true;
      });
    return pending;
  };

  function emit(
    fields: Omit<ObservationRecord, "schema" | "executionId" | "timestamp" | "eventId" | "sequence">
  ) {
    // Deliver through the public evlog drain contract. Global logger sampling, enablement,
    // and catch-and-log drain handling must not drop or falsely acknowledge accounting.
    const event: WideEvent = {
      ...identity,
      eventId: randomUUID(),
      ...fields,
      sequence: ++sequence,
      timestamp: new Date().toISOString(),
      level: fields.failed ? "error" : "info",
    };
    if (fields.failed) {
      event.error = {
        message: `Flue ${fields.event} failed`,
        why: "The runtime reported a failed operation; raw error content is omitted",
        fix: "Inspect correlated tool and model outcomes, reproduce in the sandbox, and rerun validation",
      };
    }
    void drain({ event });
  }

  const observe: FlueObservationSubscriber = (event, ctx) => {
    if (event.type === "run_start" || event.type === "run_resume") {
      workflows.set(event.runId, event.workflowName);
      return;
    }
    const base = {
      contextId: ctx.id,
      agent: event.agentName ?? ctx.agentName,
      workflow: event.runId ? workflows.get(event.runId) : undefined,
      instanceId: event.instanceId,
      submissionId: event.submissionId,
      runId: event.runId,
      session: event.session,
      parentSession: event.parentSession,
      conversationId: event.conversationId,
      taskId: event.taskId,
      operationId: event.operationId,
      turnId: event.turnId,
    };
    switch (event.type) {
      case "turn_request":
        emit({ ...base, event: event.type, purpose: event.purpose });
        break;
      case "turn": {
        const usage = usageSchema.safeParse(event.response.usage);
        // pi-ai initializes usage to zero even when the provider supplies no receipt.
        const hasUsage =
          usage.success &&
          (usage.data.input > 0 ||
            usage.data.output > 0 ||
            usage.data.cacheRead > 0 ||
            usage.data.cacheWrite > 0 ||
            usage.data.totalTokens > 0);
        emit({
          ...base,
          event: event.type,
          purpose: event.purpose,
          provider: event.request.providerId,
          requestedModel: event.request.requestedModel,
          model: event.response.responseModel ?? event.request.requestedModel,
          responseId: event.response.responseId,
          finishReason: event.response.finishReason,
          durationMs: event.durationMs,
          failed: event.isError,
          usage: usage.success ? usage.data : undefined,
          usageStatus: usage.success
            ? hasUsage
              ? "reported"
              : "unknown"
            : event.response.usage
              ? "invalid"
              : "missing",
          costStatus:
            hasUsage && usage.success && usage.data.cost.total > 0 ? "estimated" : "unknown",
        });
        break;
      }
      case "tool_start":
      case "tool":
        emit({
          ...base,
          event: event.type,
          toolCallId: event.toolCallId,
          tool: event.toolName,
          toolOrigin: event.origin,
          durationMs: event.type === "tool" ? event.durationMs : undefined,
          failed: event.type === "tool" ? event.isError : undefined,
        });
        break;
      case "operation_start":
      case "operation":
        emit({
          ...base,
          event: event.type,
          purpose: event.operationKind,
          durationMs: event.type === "operation" ? event.durationMs : undefined,
          failed: event.type === "operation" ? event.isError : undefined,
        });
        break;
      case "task_start":
      case "task":
        emit({
          ...base,
          event: event.type,
          agent: event.agent ?? base.agent,
          durationMs: event.type === "task" ? event.durationMs : undefined,
          failed: event.type === "task" ? event.isError : undefined,
        });
        break;
      case "compaction":
      case "run_end":
        // Aggregate usage is deliberately omitted: leaf turns already account for it.
        emit({ ...base, event: event.type, durationMs: event.durationMs, failed: event.isError });
        if (event.type === "run_end" && event.runId) workflows.delete(event.runId);
        break;
      case "submission_settled":
        emit({ ...base, event: event.type, failed: event.outcome !== "completed" });
        break;
    }
  };
  emit({ event: "telemetry_start" });
  const dispose = instrument({
    key: Symbol.for("flue.evlog"),
    observe,
    interceptor: (_operation, _ctx, next) => next(),
    async dispose() {
      await pending;
      // Do not certify an incomplete export with a clean shutdown marker.
      if (writeFailed) throw new Error("Flue telemetry incomplete: drain failed");
      await options.flush?.();
      emit({ event: "telemetry_stop", finalSequence: sequence + 1 });
      await pending;
      if (writeFailed) throw new Error("Flue telemetry shutdown record was not persisted");
      await options.flush?.();
    },
  });
  return { dispose, drain };
}
