import { spawnSync } from "node:child_process";
import { appendFile, mkdir, mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { fileURLToPath } from "node:url";
import { z } from "zod";
import { installObservability } from "./observability";
import { readLedger, summarize } from "flue-evlog/ledger";

const root = fileURLToPath(new URL(".", import.meta.url));
const usage =
  "Usage: npm run observe -- map [--baseline git:REF] [--json] | doctor [--dir PATH] | summary [--dir PATH]";

try {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      dir: { type: "string" },
      baseline: { type: "string" },
      json: { type: "boolean" },
      help: { type: "boolean", short: "h" },
    },
  });
  const command = positionals[0];
  if (values.help) {
    console.log(usage);
  } else if (positionals.length !== 1) {
    throw new Error(usage);
  } else if (command === "map") {
    const args = ["map", "--framework", "hono", "--json", "--no-write", "--min-score", "100"];
    if (values.baseline) args.push("--baseline", values.baseline);
    const result = spawnSync(join(root, "node_modules/.bin/evlog"), args, {
      cwd: root,
      encoding: "utf8",
    });
    process.stderr.write(result.stderr ?? "");
    if (result.error) throw result.error;
    const report = z
      .object({
        grade: z.string(),
        summary: z.object({ suppressedChecks: z.number() }),
        map: z.object({
          score: z.number(),
          routes: z.array(z.object({ file: z.string(), path: z.string(), score: z.number() })),
        }),
      })
      .parse(JSON.parse(result.stdout));
    const transport = report.map.routes.find(
      (route) => route.file === "app.ts" && route.path === "*"
    );
    if (values.json) process.stdout.write(result.stdout);
    else
      console.log(
        `Hono transport score: ${report.map.score}/100; ${report.map.routes.length} entries. Flue token coverage is checked by the flue-evlog package tests.`
      );
    if (
      result.status !== 0 ||
      !transport ||
      transport.score !== 100 ||
      report.grade === "unscored" ||
      report.summary.suppressedChecks !== 0
    ) {
      console.error(
        "Coverage gate failed. Inspect checks with npm run --silent observe -- map --json; restore instrumentation rather than suppressing checks."
      );
      process.exitCode = 1;
    }
  } else if (command === "doctor") {
    const result = spawnSync(join(root, "node_modules/.bin/evlog"), ["doctor", "--json"], {
      cwd: root,
      encoding: "utf8",
    });
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error(`evlog doctor failed: ${result.stdout}`);
    // A real write + flush + read, not merely an installed dependency or existing folder.
    const destination = values.dir ?? process.env.FLUE_LOG_DIR ?? join(root, ".evlog/logs");
    await mkdir(destination, { recursive: true });
    const directory = await mkdtemp(join(destination, ".doctor-"));
    try {
      await installObservability(directory).dispose();
      const events = await readLedger(directory);
      if (
        events.length !== 2 ||
        events[0].event !== "telemetry_start" ||
        events[1].event !== "telemetry_stop"
      ) {
        throw new Error("Telemetry startup/shutdown round trip failed");
      }
      console.log(
        JSON.stringify(
          {
            ok: true,
            evlog: JSON.parse(result.stdout),
            persistence: "write/flush/read passed",
            liveModel: "not checked",
          },
          null,
          2
        )
      );
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  } else if (command === "summary") {
    const report = summarize(
      await readLedger(values.dir ?? process.env.FLUE_LOG_DIR ?? join(root, ".evlog/logs"))
    );
    console.log(JSON.stringify(report, null, 2));
    if (process.env.GITHUB_STEP_SUMMARY) {
      // JSON in a fenced block avoids treating model/tool-controlled labels as Markdown.
      const safe = JSON.stringify(report, null, 2)
        .replaceAll("`", "\\u0060")
        .replaceAll("<", "\\u003c");
      await appendFile(
        process.env.GITHUB_STEP_SUMMARY,
        `\n### Flue token accounting\n\n\`\`\`json\n${safe}\n\`\`\`\n`
      );
    }
    if (!report.complete) process.exitCode = 1;
  } else {
    throw new Error(usage);
  }
} catch (error) {
  // Never dump raw log records or credentials on malformed input.
  console.error(
    error instanceof SyntaxError || error instanceof z.ZodError
      ? "Invalid observability data"
      : String(error)
  );
  process.exitCode = 1;
}
