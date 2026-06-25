import { getAgentDir, type ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";

type PermissionState = "allow" | "ask" | "deny";
type BashPolicy = Record<string, PermissionState>;

type CommandExtraction = {
  command: string;
  label: string;
} | null;

type ToolGuardDecision = { kind: "allow" } | { kind: "deny"; reason: string };

type ToolCallEventLike = {
  toolName?: unknown;
  input?: unknown;
};

const CONFIG_PATH_ENV_KEY = "PI_PERMISSION_SYSTEM_CONFIG_PATH";

function policyPath(): string {
  const configured = process.env[CONFIG_PATH_ENV_KEY]?.trim();
  return configured
    ? resolve(configured)
    : join(resolve(getAgentDir()), "extensions", "pi-permission-system", "config.json");
}

function parseJsoncObject(raw: string): unknown {
  // Good enough for our Nix-managed JSONC policy: strips // comments and trailing commas.
  const withoutLineComments = raw.replace(/(^|[^:])\/\/.*$/gm, "$1");
  const withoutBlockComments = withoutLineComments.replace(/\/\*[\s\S]*?\*\//g, "");
  const withoutTrailingCommas = withoutBlockComments.replace(/,\s*([}\]])/g, "$1");
  return JSON.parse(withoutTrailingCommas);
}

function loadBashPolicy(): BashPolicy {
  try {
    const raw = readFileSync(policyPath(), "utf8");
    const parsed = parseJsoncObject(raw) as { bash?: unknown; permission?: unknown };
    const permission =
      parsed.permission && typeof parsed.permission === "object"
        ? (parsed.permission as { bash?: unknown })
        : parsed;
    if (!permission.bash || typeof permission.bash !== "object") return {};

    const policy: BashPolicy = {};
    for (const [pattern, state] of Object.entries(permission.bash as Record<string, unknown>)) {
      if (state === "allow" || state === "ask" || state === "deny") {
        policy[pattern] = state;
      }
    }
    return policy;
  } catch {
    return {};
  }
}

function wildcardToRegExp(pattern: string): RegExp {
  const escaped = pattern.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*");
  return new RegExp(`^${escaped}$`);
}

function checkBashPolicy(command: string): { state: PermissionState | null; pattern?: string } {
  const policy = loadBashPolicy();
  let result: { state: PermissionState; pattern: string } | null = null;

  // pi-permission-system/OpenCode-compatible wildcard ordering is last match wins.
  for (const [pattern, state] of Object.entries(policy)) {
    if (wildcardToRegExp(pattern).test(command)) {
      result = { state, pattern };
    }
  }

  return result ?? { state: null };
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" ? (value as Record<string, unknown>) : {};
}

function stringField(record: Record<string, unknown>, key: string): string | null {
  const value = record[key];
  return typeof value === "string" && value.trim() ? value : null;
}

export function extractCommand(toolName: string, input: unknown): CommandExtraction {
  const record = asRecord(input);

  if (toolName === "process") {
    const action = stringField(record, "action");
    const command = stringField(record, "command");
    if (action === "start" && command) return { command, label: "process.start" };
    return null;
  }

  if (toolName === "interactive_shell") {
    const command = stringField(record, "command");
    if (command) return { command, label: "interactive_shell" };
    return null;
  }

  if (toolName === "bash") {
    const command = stringField(record, "command");
    if (command) return { command, label: "bash" };
    return null;
  }

  if (toolName === "herdr_run_in_pane") {
    const command = stringField(record, "command");
    if (command) return { command, label: "herdr_run_in_pane" };
    return null;
  }

  return null;
}

export function evaluateToolGuard(event: ToolCallEventLike): ToolGuardDecision {
  const toolName = typeof event.toolName === "string" ? event.toolName : "";
  const extracted = extractCommand(toolName, event.input);

  if (extracted) {
    const check = checkBashPolicy(extracted.command);
    if (check.state === "deny") {
      return {
        kind: "deny",
        reason: `${extracted.label} command denied by bash policy${check.pattern ? ` (${check.pattern})` : ""}: ${extracted.command}`,
      };
    }
    return { kind: "allow" };
  }

  return { kind: "allow" };
}

export default function commandPolicyBridge(pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    const decision = evaluateToolGuard(event);
    if (decision.kind === "deny") {
      return { block: true, reason: decision.reason };
    }
    return undefined;
  });
}
