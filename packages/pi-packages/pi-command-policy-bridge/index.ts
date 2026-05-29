import {
    getAgentDir,
    type ExtensionAPI,
    type ExtensionContext,
} from "@mariozechner/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

type PermissionState = "allow" | "ask" | "deny";
type BashPolicy = Record<string, PermissionState>;

type CommandExtraction = {
    command: string;
    label: string;
} | null;

type ToolGuardDecision =
    | { kind: "allow" }
    | { kind: "ask"; title: string; message: string; denyReason: string }
    | { kind: "deny"; reason: string };

type ToolCallEventLike = {
    toolName?: unknown;
    input?: unknown;
    workingDirectory?: unknown;
};

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

function inputAction(input: unknown): string | null {
    const value = stringField(asRecord(input), "action");
    return value ? value.trim().toLowerCase() : null;
}

function eventWorkingDirectory(event: ToolCallEventLike): string {
    const value = typeof event.workingDirectory === "string" ? event.workingDirectory.trim() : "";
    return value || process.cwd();
}

export function isJjRepo(cwd: string): boolean {
    let current = resolve(cwd);
    while (true) {
        if (existsSync(join(current, ".jj"))) return true;
        const parent = dirname(current);
        if (parent === current) return false;
        current = parent;
    }
}

function isGitWriteCommand(command: string): boolean {
    const lower = command.trim().toLowerCase();
    const patterns = [
        /\bgit\s+add\b/,
        /\bgit\s+commit\b/,
        /\bgit\s+reset\b/,
        /\bgit\s+checkout\b/,
        /\bgit\s+rebase\b/,
        /\bgit\s+merge\b/,
        /\bgit\s+push\b/,
    ];
    return patterns.some((pattern) => pattern.test(lower));
}

function gitRemediation(command: string): string | null {
    const lower = command.toLowerCase();
    if (/\bgit\s+add\b/.test(lower)) {
        return "jj snapshots automatically; use `jj diff` and continue.";
    }
    if (/\bgit\s+commit\b/.test(lower)) {
        return 'use `jj describe -m "..."` then `jj new --no-edit`.';
    }
    if (/\bgit\s+reset\b/.test(lower)) {
        return "use `jj restore`, `jj abandon`, or ask before destructive cleanup.";
    }
    if (/\bgit\s+push\b/.test(lower)) {
        return "use `/jj-align-push <branch>` or `jj_vcs align_push` after status.";
    }
    if (/\bgit\s+checkout\b|\bgit\s+rebase\b|\bgit\s+merge\b/.test(lower)) {
        return "prefer jj history/edit commands (`jj new`, `jj rebase`, `jj squash`) in jj repos.";
    }
    return null;
}

function isJjTool(toolName: string): boolean {
    return toolName === "jj_vcs" || toolName === "jj_stack_pr_flow" || toolName === "jj_workspace";
}

function isMutatingJjAction(toolName: string, action: string): boolean {
    if (toolName === "jj_vcs") return action === "align_push";
    if (toolName === "jj_stack_pr_flow") {
        return action === "publish" || action === "sync" || action === "close" || action === "init";
    }
    if (toolName === "jj_workspace") {
        return action === "create" || action === "squash" || action === "delete";
    }
    return false;
}

export function evaluateToolGuard(event: ToolCallEventLike): ToolGuardDecision {
    const toolName = typeof event.toolName === "string" ? event.toolName : "";
    const extracted = extractCommand(toolName, event.input);

    if (extracted) {
        const cwd = eventWorkingDirectory(event);
        if (isJjRepo(cwd) && isGitWriteCommand(extracted.command)) {
            const remediation = gitRemediation(extracted.command);
            return {
                kind: "deny",
                reason: remediation
                    ? `Git mutation blocked in jj repo: ${extracted.command}. ${remediation}`
                    : `Git mutation blocked in jj repo: ${extracted.command}`,
            };
        }

        const check = checkBashPolicy(extracted.command);
        if (check.state === "deny") {
            return {
                kind: "deny",
                reason: `${extracted.label} command denied by bash policy${check.pattern ? ` (${check.pattern})` : ""}: ${extracted.command}`,
            };
        }
        if (check.state === "ask" || check.state === null) {
            return {
                kind: "ask",
                title: "Command requires approval",
                message: `${extracted.label} wants to run:\n\n${extracted.command}\n\nMatched policy: ${check.pattern ?? "<default ask>"}`,
                denyReason: `${extracted.label} command was not approved: ${extracted.command}`,
            };
        }
        return { kind: "allow" };
    }

    if (isJjTool(toolName)) {
        const action = inputAction(event.input);
        if (action && isMutatingJjAction(toolName, action)) {
            return {
                kind: "ask",
                title: "JJ action requires approval",
                message: `${toolName}.${action} mutates VCS state and requires approval.`,
                denyReason: `${toolName}.${action} was not approved`,
            };
        }
    }

    return { kind: "allow" };
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
        const decision = evaluateToolGuard(event);
        if (decision.kind === "deny") {
            return { block: true, reason: decision.reason };
        }
        if (decision.kind === "ask") {
            const allowed = await confirmAsk(ctx, decision.title, decision.message);
            if (!allowed) {
                return { block: true, reason: decision.denyReason };
            }
        }
        return undefined;
    });
}
