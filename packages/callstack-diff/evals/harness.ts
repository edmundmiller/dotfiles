import { spawnSync } from "node:child_process";
import { cpSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import { createHarness } from "vitest-evals";

import type { ComplaintCase } from "./cases.ts";
import { runPlainPi } from "./pi.ts";

const PACKAGE_ROOT = fileURLToPath(new URL("..", import.meta.url));
const CLI_SOURCE = join(PACKAGE_ROOT, "src", "cli.ts");
export const TOOL_EXTENSION = `export default function callstackDiffEvalTool(pi) {
  pi.registerTool({
    name: "callstack_diff",
    label: "callstack-diff",
    description: "Run the fixed csd command for this evaluation case.",
    parameters: { type: "object", properties: {}, additionalProperties: false },
    async execute(_toolCallId, _params, signal) {
      let args;
      try {
        args = JSON.parse(process.env.CALLSTACK_DIFF_EVAL_CSD_ARGS || "[]");
      } catch {
        args = [];
      }
      if (!Array.isArray(args) || !args.every((value) => typeof value === "string")) {
        return {
          content: [{ type: "text", text: "Invalid CALLSTACK_DIFF_EVAL_CSD_ARGS" }],
          isError: true,
        };
      }

      const result = await pi.exec(process.env.CALLSTACK_DIFF_EVAL_BUN_BIN || "bun", args, {
        signal,
        timeout: 120000,
      });
      const text = [result.stdout, result.stderr].filter(Boolean).join("\\n").trim();
      return {
        content: [{ type: "text", text }],
        details: { command: process.env.CALLSTACK_DIFF_EVAL_PUBLIC_COMMAND, exitCode: result.code },
        isError: result.code !== 0,
      };
    },
  });
}
`;

export function createComplaintHarness() {
  return createHarness<ComplaintCase, string>({
    name: "callstack-diff-plain-pi",
    run: async ({ input, signal, setArtifact }) => {
      const temporaryRoot = mkdtempSync(join(tmpdir(), "callstack-diff-eval-"));
      const workspace = join(temporaryRoot, "fixture");
      const extension = join(temporaryRoot, "callstack-diff-tool.mjs");

      try {
        cpSync(join(PACKAGE_ROOT, "evals", "fixtures", input.fixture), workspace, {
          recursive: true,
        });
        writeFileSync(extension, TOOL_EXTENSION);

        const prompt = renderPrompt(input);
        const output = await runPlainPi(
          prompt,
          workspace,
          signal,
          {
            CALLSTACK_DIFF_EVAL_BUN_BIN: resolveBun(),
            CALLSTACK_DIFF_EVAL_CSD_ARGS: JSON.stringify([
              "run",
              CLI_SOURCE,
              ...input.command.slice(1),
            ]),
            CALLSTACK_DIFF_EVAL_PUBLIC_COMMAND: input.command.join(" "),
          },
          extension
        );

        setArtifact("caseId", input.id);
        setArtifact("runner", "plain-pi");
        setArtifact("complaint", output);
        return {
          output,
          events: [
            { type: "message", role: "user", content: prompt },
            { type: "message", role: "assistant", content: output },
          ],
        };
      } finally {
        rmSync(temporaryRoot, { recursive: true, force: true });
      }
    },
  });
}

function resolveBun(): string {
  const configured = process.env.CALLSTACK_DIFF_EVAL_BUN_BIN;
  if (configured) return configured;
  const result = spawnSync("which", ["bun"], { encoding: "utf8" });
  const bun = result.stdout.trim();
  if (result.status !== 0 || !bun) {
    throw new Error("bun is required; set CALLSTACK_DIFF_EVAL_BUN_BIN to its absolute path");
  }
  return bun;
}

function renderPrompt(testCase: ComplaintCase): string {
  return `You are a plain Pi agent evaluating the public csd command in a disposable fixture.
Use only read and callstack_diff. You have no shell, edit, or write tool.

Task:
${testCase.task}

Invoke callstack_diff once. It runs this exact public command:
${testCase.command.join(" ")}

Return exactly one JSON object, with no markdown fence or surrounding prose:
{
  "caseId": "${testCase.id}",
  "kind": "bug" | "limitation" | "use-case",
  "title": "specific complaint title",
  "summary": "why the behavior matters",
  "command": "the exact reproducing command",
  "expected": "the evidence-backed expected behavior",
  "actual": "the observed output and conflicting evidence",
  "regressionTest": "a concrete automated test that would preserve the expected behavior"
}`;
}
