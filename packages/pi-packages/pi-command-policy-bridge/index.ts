import {
  getAgentDir,
  type ExtensionAPI,
  type ExtensionContext,
} from "@mariozechner/pi-coding-agent";
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";

type PermissionState = "allow" | "ask" | "deny";
type BashPolicy = Record<string, PermissionState>;

type CommandExtraction = {
  command: string;
  label: string;
} | null;

const POLICY_AGENT_DIR_ENV_KEY = "PI_PERMISSION_SYSTEM_POLICY_AGENT_DIR";

function policyPath(): string {
  const agentDir = process.env[POLICY_AGENT_DIR_ENV_KEY]?.trim() || getAgentDir();
  return join(resolve(agentDir), "pi-permissions.jsonc");
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
    const parsed = parseJsoncObject(raw) as { bash?: unknown };
    if (!parsed.bash || typeof parsed.bash !== "object") return {};

    const policy: BashPolicy = {};
    for (const [pattern, state] of Object.entries(parsed.bash as Record<string, unknown>)) {
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

function extractCommand(toolName: string, input: unknown): CommandExtraction {
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

  if (toolName === "herdr_run_in_pane") {
    const command = stringField(record, "command");
    if (command) return { command, label: "herdr_run_in_pane" };
    return null;
  }

  return null;
}

async function confirmAsk(ctx: ExtensionContext, title: string, message: string): Promise<boolean> {
  if (!ctx.hasUI) return false;
  const ui = ctx.ui as unknown as {
    confirm?: (title: string, message: string) => Promise<boolean>;
    select?: (message: string, options: string[]) => Promise<string>;
  };

  if (typeof ui.confirm === "function") {
    return ui.confirm(title, message);
  }

  if (typeof ui.select === "function") {
    return (await ui.select(`${title}\n\n${message}`, ["Allow", "Deny"])) === "Allow";
  }

  return false;
}

export default function commandPolicyBridge(pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    const toolName = typeof event.toolName === "string" ? event.toolName : "";
    const extracted = extractCommand(toolName, event.input);
    if (!extracted) return undefined;

    const check = checkBashPolicy(extracted.command);

    if (check.state === "deny") {
      return {
        block: true,
        reason: `${extracted.label} command denied by bash policy${check.pattern ? ` (${check.pattern})` : ""}: ${extracted.command}`,
      };
    }

    if (check.state === "ask" || check.state === null) {
      const allowed = await confirmAsk(
        ctx,
        "Command requires approval",
        `${extracted.label} wants to run:\n\n${extracted.command}\n\nMatched policy: ${check.pattern ?? "<default ask>"}`
      );
      if (!allowed) {
        return {
          block: true,
          reason: `${extracted.label} command was not approved: ${extracted.command}`,
        };
      }
    }

    return undefined;
  });
}
