import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import { z } from "zod";
import { recordSchema, type ObservationRecord } from "./index.js";

export async function readLedger(dir: string) {
  const records = new Map<string, ObservationRecord>();
  for (const file of (await readdir(dir)).filter((name) => name.endsWith(".jsonl")).sort()) {
    const lines = (await readFile(join(dir, file), "utf8")).split("\n");
    for (const [index, line] of lines.entries()) {
      if (!line.trim()) continue;
      const value = z.record(z.string(), z.unknown()).parse(JSON.parse(line));
      // HTTP transport events are separate from the token ledger.
      if (!("schema" in value)) continue;
      const parsed = recordSchema.safeParse(value);
      if (!parsed.success) throw new Error(`${file}:${index + 1}: invalid Flue ledger schema`);
      const prior = records.get(parsed.data.eventId);
      if (prior && JSON.stringify(prior) !== JSON.stringify(parsed.data)) {
        throw new Error(`${file}:${index + 1}: conflicting event identity`);
      }
      records.set(parsed.data.eventId, parsed.data);
    }
  }
  if (!records.size) throw new Error("No Flue events found; an empty ledger is not healthy");
  return [...records.values()];
}

export function summarize(records: ObservationRecord[]) {
  const groups = new Map<
    string,
    {
      agent: string;
      model: string;
      purpose: string;
      calls: number;
      missingUsage: number;
      unknownCost: number;
      input: number;
      output: number;
      cacheRead: number;
      cacheWrite: number;
      totalTokens: number;
      estimatedCostUsd: number | null;
    }
  >();
  const boundaries = new Map<string, { starts: number; ends: number }>();
  const issues: string[] = [];
  const seen = new Set<string>();
  const executions = new Map<string, { sequences: Set<number>; finalSequence?: number }>();
  let failures = 0;
  let turns = 0;
  for (const event of records) {
    if (seen.has(event.eventId)) continue;
    seen.add(event.eventId);
    const execution = executions.get(event.executionId) ?? { sequences: new Set<number>() };
    if (execution.sequences.has(event.sequence)) {
      issues.push(`execution ${event.executionId}: duplicate sequence ${event.sequence}`);
    }
    execution.sequences.add(event.sequence);
    if (event.event === "telemetry_start" && event.sequence !== 1) {
      issues.push(`execution ${event.executionId}: startup is not first`);
    }
    if (event.event === "telemetry_stop") {
      execution.finalSequence = event.finalSequence;
      if (event.finalSequence !== event.sequence) {
        issues.push(`execution ${event.executionId}: invalid shutdown count`);
      }
    }
    executions.set(event.executionId, execution);
    if (event.failed) failures++;
    let kind: string | undefined;
    let id: string | undefined;
    const start = event.event.endsWith("_start") || event.event === "turn_request";
    switch (event.event) {
      case "telemetry_start":
      case "telemetry_stop":
        kind = "telemetry";
        id = event.executionId;
        break;
      case "turn_request":
      case "turn":
        kind = "turn";
        id = event.turnId;
        break;
      case "tool_start":
      case "tool":
        kind = "tool";
        // Provider IDs are only turn-local; caller shell tools may have no model turn.
        if (event.toolOrigin === "model" && !event.turnId) {
          issues.push(`tool ${event.toolCallId}: missing model turn`);
        }
        id = event.toolCallId
          ? JSON.stringify([event.turnId, event.operationId, event.session, event.toolCallId])
          : undefined;
        break;
      case "operation_start":
      case "operation":
        kind = "operation";
        id = event.operationId;
        break;
      case "task_start":
      case "task":
        kind = "task";
        id = event.taskId;
        break;
    }
    if (kind) {
      if (!id) issues.push(`${event.event}: missing correlation ID`);
      const key = JSON.stringify([event.executionId, event.contextId, kind, id]);
      const boundary = boundaries.get(key) ?? { starts: 0, ends: 0 };
      if (start) boundary.starts++;
      else boundary.ends++;
      boundaries.set(key, boundary);
    }
    if (event.event !== "turn") continue;
    turns++;
    if ((!event.agent && !event.workflow) || !event.model || !event.purpose || !event.contextId) {
      issues.push(`turn ${event.turnId}: missing attribution`);
    }
    const labels = {
      agent: event.agent ?? (event.workflow ? `workflow:${event.workflow}` : "unknown"),
      model: event.model ?? "unknown",
      purpose: event.purpose ?? "unknown",
    };
    const key = JSON.stringify(labels);
    const group = groups.get(key) ?? {
      ...labels,
      calls: 0,
      missingUsage: 0,
      unknownCost: 0,
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      estimatedCostUsd: 0,
    };
    group.calls++;
    if (!event.usage || event.usageStatus !== "reported") {
      group.missingUsage++;
      issues.push(`turn ${event.turnId}: usage ${event.usageStatus ?? "missing"}`);
    } else {
      for (const field of ["input", "output", "cacheRead", "cacheWrite", "totalTokens"] as const) {
        group[field] += event.usage[field];
      }
    }
    if (!event.usage || event.usageStatus !== "reported" || event.costStatus !== "estimated") {
      group.unknownCost++;
      group.estimatedCostUsd = null;
      issues.push(`turn ${event.turnId}: cost estimate unavailable`);
    } else if (group.estimatedCostUsd !== null) {
      group.estimatedCostUsd += event.usage.cost.total;
    }
    groups.set(key, group);
  }
  for (const [key, boundary] of boundaries) {
    if (boundary.starts !== 1 || boundary.ends !== 1) {
      issues.push(`${key}: ${boundary.starts} starts, ${boundary.ends} completions`);
    }
  }
  if (!turns) issues.push("No model turns recorded");
  for (const [executionId, execution] of executions) {
    const sequences = [...execution.sequences].sort((a, b) => a - b);
    if (
      sequences.some((sequence, index) => sequence !== index + 1) ||
      execution.finalSequence !== sequences.length
    ) {
      issues.push(`execution ${executionId}: missing events or shutdown count`);
    }
    if (!boundaries.has(JSON.stringify([executionId, undefined, "telemetry", executionId]))) {
      issues.push(`execution ${executionId}: no telemetry lifecycle recorded`);
    }
  }
  return {
    complete: issues.length === 0,
    turns,
    failures,
    issues,
    groups: [...groups.values()],
    costSource: "Flue/pi-ai pricing estimate; not provider billing",
    reasoningTokens: "unavailable in Flue beta.9",
  };
}
