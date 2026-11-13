import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { realpath } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { Type } from "typebox";
import { Value } from "typebox/value";
import { thimbleCoverageReport } from "./thimble-coverage.js";
import { checkThimbleEvidence } from "./thimble-evidence.js";
import { parseThimbleJson, thimbleJsonSchema, type ThimbleJson } from "./thimble-json.js";
import {
  loadThimbleLabels,
  runThimbleLabel,
  saveThimbleLabelAnswers,
  thimbleLabelDirectory,
} from "./thimble-labels.js";

/** Run native TypeScript analysis, isolating labels by Pi session and real working folder. */
export async function runThimbleEngine<T>(
  ctx: ExtensionContext,
  operation: "coverage" | "evidence" | "label" | "label_answers",
  payload: T,
  signal?: AbortSignal
): Promise<ThimbleJson> {
  const deadline = AbortSignal.timeout(60_000);
  const combined = signal ? AbortSignal.any([signal, deadline]) : deadline;
  combined.throwIfAborted();
  const root = await realpath(ctx.cwd);
  const session = `pi-${ctx.sessionManager.getSessionId()}`;
  const directory = thimbleLabelDirectory(
    root,
    process.env.THIMBLE_PI_HOME || join(homedir(), ".pi", "agent", "thimble"),
    session
  );
  const request = parseThimbleJson(JSON.stringify(payload));
  let result: ThimbleJson;
  switch (operation) {
    case "evidence":
      result = await checkThimbleEvidence(root, request, combined);
      break;
    case "label":
      result = await runThimbleLabel(root, directory, session, request, combined);
      break;
    case "label_answers":
      result = await saveThimbleLabelAnswers(root, directory, request, combined);
      break;
    case "coverage": {
      const { seen } = Value.Parse(Type.Object({ seen: Type.Array(thimbleJsonSchema) }), request);
      result = await thimbleCoverageReport(
        root,
        seen,
        await loadThimbleLabels(directory),
        combined
      );
      break;
    }
  }
  combined.throwIfAborted();
  if (Buffer.byteLength(JSON.stringify(result)) > 4 * 1024 * 1024)
    throw new Error("Thimble engine output exceeded 4 MiB. Use a smaller label scope.");
  return result;
}
