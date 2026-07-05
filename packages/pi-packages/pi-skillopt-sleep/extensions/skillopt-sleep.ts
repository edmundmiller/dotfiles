import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

const RUNNER = fileURLToPath(new URL("../scripts/skillopt-sleep-omp.py", import.meta.url));
const DEFAULT_TIMEOUT_MS = 10 * 60 * 1000;

const ACTIONS = ["status", "harvest", "dry-run", "run", "adopt", "schedule", "unschedule"] as const;
type Action = (typeof ACTIONS)[number];

const textResult = (text: string, details: Record<string, unknown> = {}) => ({
  content: [{ type: "text" as const, text }],
  details,
});

const splitArgs = (input: string): string[] => {
  const args: string[] = [];
  let current = "";
  let quote: '"' | "'" | null = null;
  let escaped = false;

  for (const char of input) {
    if (escaped) {
      current += char;
      escaped = false;
      continue;
    }
    if (char === "\\") {
      escaped = true;
      continue;
    }
    if (quote) {
      if (char === quote) quote = null;
      else current += char;
      continue;
    }
    if (char === '"' || char === "'") {
      quote = char;
      continue;
    }
    if (/\s/.test(char)) {
      if (current) {
        args.push(current);
        current = "";
      }
      continue;
    }
    current += char;
  }

  if (escaped) current += "\\";
  if (current) args.push(current);
  return args;
};

const runSkillOpt = async (
  pi: ExtensionAPI,
  args: string[],
  options: { cwd: string; timeoutMs?: number }
) => {
  const result = await pi.exec("python3", [RUNNER, ...args], {
    cwd: options.cwd,
    timeout: options.timeoutMs ?? DEFAULT_TIMEOUT_MS,
  });
  const stdout = result.stdout?.trim() ?? "";
  const stderr = result.stderr?.trim() ?? "";
  if (result.code !== 0) {
    throw new Error(
      [`skillopt-sleep failed with exit code ${result.code}`, stdout, stderr]
        .filter(Boolean)
        .join("\n\n")
    );
  }
  return { stdout, stderr, code: result.code };
};

export default function skilloptSleepExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "skillopt_sleep_omp",
    label: "SkillOpt Sleep for OMP",
    description:
      "Run Microsoft SkillOpt-Sleep over local OMP sessions via status, harvest, dry-run, run, adopt, schedule, or unschedule.",
    parameters: Type.Object({
      action: Type.Union(
        [
          Type.Literal("status"),
          Type.Literal("harvest"),
          Type.Literal("dry-run"),
          Type.Literal("run"),
          Type.Literal("adopt"),
          Type.Literal("schedule"),
          Type.Literal("unschedule"),
        ],
        { description: "SkillOpt-Sleep action to run." }
      ),
      args: Type.Optional(
        Type.Array(Type.String(), {
          description:
            "Additional SkillOpt-Sleep flags, e.g. ['--backend', 'mock', '--max-tasks', '3'].",
        })
      ),
      timeoutMs: Type.Optional(
        Type.Number({ description: "Command timeout in milliseconds. Defaults to 10 minutes." })
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const action = params.action as Action;
      const args = [action, ...((params.args as string[] | undefined) ?? [])];
      const result = await runSkillOpt(pi, args, {
        cwd: ctx.cwd,
        timeoutMs: params.timeoutMs as number | undefined,
      });
      return textResult(result.stdout || result.stderr || "skillopt-sleep completed", result);
    },
  });

  pi.registerCommand("skillopt-sleep", {
    description: "Run SkillOpt-Sleep for OMP, e.g. /skillopt-sleep dry-run --backend mock",
    handler: async (input, ctx) => {
      const args = splitArgs(input.trim() || "status");
      try {
        const result = await runSkillOpt(pi, args, { cwd: ctx.cwd });
        ctx.ui.notify(result.stdout || result.stderr || "skillopt-sleep completed", "info");
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
      }
    },
  });
}
