import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createServer } from "node:http";
import {
  copyFile,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { test } from "node:test";
import { z } from "zod";
import { createLogger, initLogger } from "evlog";
import { writeToFs } from "evlog/fs";
import { installFlueEvlog, type ObservationRecord } from "flue-evlog";
import { readLedger, summarize } from "flue-evlog/ledger";

const exec = promisify(execFile);
const root = fileURLToPath(new URL("..", import.meta.url));

test(
  "real Flue CLI records model usage and tool failure without recording content",
  { timeout: 120_000 },
  async (t) => {
    const dir = await mkdtemp(join(tmpdir(), "flue-observe-test-"));
    t.after(() => rm(dir, { recursive: true, force: true }));
    const logs = join(dir, "logs");
    await mkdir(join(dir, "agents"));
    await symlink(join(root, "node_modules"), join(dir, "node_modules"), "dir");
    await writeFile(join(dir, "package.json"), JSON.stringify({ type: "module" }));
    await writeFile(
      join(dir, "app.ts"),
      `
      import { flue } from "@flue/runtime/routing";
      import { initLogger } from "evlog";
      import { writeToFs } from "evlog/fs";
      import { installFlueEvlog } from ${JSON.stringify(join(root, "dist/index.js"))};
      // The host can disable its logger without dropping accounting events.
      initLogger({ enabled: false });
      installFlueEvlog({
        service: "fixture",
        drain: ({ event }) => writeToFs(event, { dir: process.env.FLUE_LOG_DIR, pretty: false }),
        metadata: { pr: "42", target: "hunk" },
      });
      export default flue();
    `
    );
    let calls = 0;
    let providerFails = false;
    let omitUsage = false;
    let reuseToolId = false;
    const server = createServer(async (req, res) => {
      for await (const _chunk of req) {
        /* Consume the request, never log its content. */
      }
      calls++;
      if (providerFails) {
        res.writeHead(401, { "content-type": "application/json" });
        res.end(
          JSON.stringify({
            error: { message: "PRIVATE_PROVIDER_ERROR", type: "authentication_error" },
          })
        );
        return;
      }
      res.writeHead(200, { "content-type": "text/event-stream" });
      const chunk = (
        choices: unknown[],
        usage?: {
          prompt_tokens: number;
          completion_tokens: number;
          total_tokens: number;
          prompt_tokens_details: { cached_tokens: number };
        }
      ) =>
        res.write(
          `data: ${JSON.stringify({
            id: `response-${calls}`,
            object: "chat.completion.chunk",
            created: 1,
            model: "gpt-4o",
            choices,
            usage,
          })}\n\n`
        );
      if (calls === 1 || (reuseToolId && calls === 2)) {
        chunk([
          {
            index: 0,
            delta: {
              role: "assistant",
              tool_calls: [
                {
                  index: 0,
                  id: "call-1",
                  type: "function",
                  function: { name: "probe", arguments: "{}" },
                },
              ],
            },
            finish_reason: null,
          },
        ]);
        chunk([{ index: 0, delta: {}, finish_reason: "tool_calls" }]);
        chunk([], {
          prompt_tokens: 113,
          completion_tokens: 7,
          total_tokens: 120,
          prompt_tokens_details: { cached_tokens: 13 },
        });
      } else {
        chunk([
          {
            index: 0,
            delta: { role: "assistant", content: "PRIVATE_MODEL_RESPONSE" },
            finish_reason: null,
          },
        ]);
        chunk([{ index: 0, delta: {}, finish_reason: "stop" }]);
        if (!omitUsage) {
          chunk([], {
            prompt_tokens: 211,
            completion_tokens: 11,
            total_tokens: 222,
            prompt_tokens_details: { cached_tokens: 31 },
          });
        }
      }
      res.end("data: [DONE]\n\n");
    });
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    t.after(
      () =>
        new Promise<void>((resolve, reject) =>
          server.close((err) => (err ? reject(err) : resolve()))
        )
    );
    const address = z.object({ port: z.number() }).parse(server.address());
    await writeFile(
      join(dir, "agents/probe.ts"),
      `
    import { defineAgent, defineTool, registerProvider } from "@flue/runtime";
    import { local } from "@flue/runtime/node";
    registerProvider("openai", { api: "openai-completions", baseUrl: "http://127.0.0.1:${address.port}/v1", apiKey: "PRIVATE_PROVIDER_KEY" });
    export default defineAgent(() => ({
      model: process.env.FIXTURE_MODEL ?? "openai/gpt-4o", instructions: "PRIVATE_SYSTEM_PROMPT",
      sandbox: local(),
      compaction: { keepRecentTokens: 1, reserveTokens: 1024 },
      tools: [defineTool({ name: "probe", description: "Test a failing tool", run() { throw new Error("PRIVATE_TOOL_ERROR"); } })],
    }));
  `
    );
    const result = await exec(
      process.execPath,
      [
        join(root, "node_modules/@flue/cli/bin/flue.mjs"),
        "run",
        "probe",
        "--root",
        dir,
        "--target",
        "node",
        "--id",
        "fixture-instance",
        "--input",
        '{"message":"PRIVATE_USER_PROMPT"}',
      ],
      {
        env: {
          PATH: process.env.PATH,
          HOME: dir,
          FLUE_LOG_DIR: logs,
          PR_NUMBER: "42",
          TARGET: "hunk",
          FLUE_COMMIT: "fixture-commit",
        },
        timeout: 100_000,
      }
    );
    assert.match(result.stdout, /PRIVATE_MODEL_RESPONSE/);
    assert.equal(calls, 2);
    const records = await readLedger(logs);
    const report = summarize(records);
    assert.deepEqual(report.issues, []);
    assert.equal(report.complete, true);
    assert.equal(report.turns, 2);
    assert.equal(report.groups.length, 1);
    assert.equal(report.failures, 1);
    assert.deepEqual(
      { ...report.groups[0], estimatedCostUsd: undefined },
      {
        agent: "probe",
        model: "gpt-4o",
        purpose: "agent",
        calls: 2,
        missingUsage: 0,
        unknownCost: 0,
        input: 280,
        output: 18,
        cacheRead: 44,
        cacheWrite: 0,
        totalTokens: 342,
        estimatedCostUsd: undefined,
      }
    );
    assert(report.groups[0].estimatedCostUsd !== null && report.groups[0].estimatedCostUsd > 0);
    assert(
      records.some((event) => event.event === "tool" && event.tool === "probe" && event.failed)
    );
    assert(
      records
        .filter((event) => event.event === "turn")
        .every(
          (event) =>
            event.instanceId === "fixture-instance" && event.pr === "42" && event.target === "hunk"
        )
    );
    for (const file of (await readdir(logs)).filter((name) => name.endsWith(".jsonl"))) {
      const text = await readFile(join(logs, file), "utf8");
      assert.doesNotMatch(text, /PRIVATE_/);
      assert.match(text, /"level":"error"/);
    }

    const run = async (name: string, destination: string, model = "openai/gpt-4o") => {
      await exec(
        process.execPath,
        [
          join(root, "node_modules/@flue/cli/bin/flue.mjs"),
          "run",
          name,
          "--root",
          dir,
          "--target",
          "node",
          ...(name === "probe" ? ["--input", '{"message":"PRIVATE_USER_PROMPT"}'] : []),
        ],
        {
          env: {
            PATH: process.env.PATH,
            HOME: dir,
            FLUE_LOG_DIR: destination,
            FIXTURE_MODEL: model,
          },
          timeout: 60_000,
        }
      );
      return readLedger(destination);
    };
    await t.test("missing provider usage is unknown, not zero", async () => {
      omitUsage = true;
      try {
        const missing = summarize(await run("probe", join(dir, "missing-usage")));
        assert.equal(missing.complete, false);
        assert.equal(missing.groups[0].missingUsage, 1);
      } finally {
        omitUsage = false;
      }
    });
    await t.test("reused tool IDs in different model turns remain distinct", async () => {
      calls = 0;
      reuseToolId = true;
      try {
        const repeated = await run("probe", join(dir, "repeated-tool"));
        assert.equal(
          repeated.filter((event) => event.event === "tool" && event.toolCallId === "call-1")
            .length,
          2
        );
        const report = summarize(repeated);
        assert.deepEqual(report.issues, []);
        assert.equal(report.groups[0].totalTokens, 462);
        assert.equal(
          summarize(
            repeated.filter(
              (event) =>
                event.event !== "tool" ||
                event.turnId !== repeated.find((event) => event.event === "tool")?.turnId
            )
          ).complete,
          false
        );
      } finally {
        reuseToolId = false;
      }
    });
    await t.test("unknown model pricing is not reported as free", async () => {
      const unpriced = await run("probe", join(dir, "unpriced"), "openai/fixture-unpriced");
      const report = summarize(unpriced);
      assert.equal(report.complete, false);
      assert.equal(report.groups[0].totalTokens, 222);
      assert.equal(report.groups[0].missingUsage, 0);
      assert.equal(report.groups[0].unknownCost, 1);
      assert.equal(report.groups[0].estimatedCostUsd, null);
    });
    await t.test("whole missing pairs and batches cannot certify complete accounting", async () => {
      const turn = records.find((event) => event.event === "turn");
      assert(turn);
      assert.equal(
        summarize(records.filter((event) => event.turnId !== turn.turnId)).complete,
        false
      );
      const directory = join(dir, "partial-export");
      await mkdir(directory);
      await writeFile(join(directory, "start.jsonl"), JSON.stringify(records[0]) + "\n");
      await writeFile(
        join(directory, "end.jsonl"),
        records
          .slice(-3)
          .map((event) => JSON.stringify(event))
          .join("\n")
      );
      assert.equal(summarize(await readLedger(directory)).complete, false);
    });
    await t.test("real split-prefix compaction counts every model leaf exactly once", async () => {
      await mkdir(join(dir, "workflows"));
      await writeFile(
        join(dir, "workflows/compact.ts"),
        `
        import { defineWorkflow } from "@flue/runtime";
        import agent from "../agents/probe";
        export default defineWorkflow({
          agent,
          async run({ harness }) {
            await harness.shell("printf caller");
            await (await harness.session("shell-only")).shell("printf session");
            const session = await harness.session("regression");
            await session.prompt("PRIVATE_OLD_USER");
            await session.prompt("PRIVATE_CURRENT_USER");
            await session.compact();
            await session.prompt("PRIVATE_AFTER_COMPACT");
            return { ok: true };
          },
        });
      `
      );
      const before = calls;
      const compacted = await run("compact", join(dir, "compacted"));
      assert.equal(calls - before, 5);
      assert(compacted.some((event) => event.event === "compaction" && !event.failed));
      const callerTools = compacted.filter(
        (event) => event.event === "tool" && event.toolOrigin === "caller"
      );
      assert.equal(callerTools.length, 2);
      assert(callerTools.every((event) => !event.turnId));
      const report = summarize(compacted);
      assert.deepEqual(report.issues, []);
      assert.equal(report.turns, 5);
      assert.equal(
        report.groups.reduce((sum, group) => sum + group.totalTokens, 0),
        1110
      );
      for (const purpose of ["compaction", "compaction_prefix"]) {
        assert.equal(report.groups.find((group) => group.purpose === purpose)?.calls, 1);
      }
      for (const file of (await readdir(join(dir, "compacted"))).filter((name) =>
        name.endsWith(".jsonl")
      )) {
        assert.doesNotMatch(await readFile(join(dir, "compacted", file), "utf8"), /PRIVATE_/);
      }
    });
    providerFails = true;
    const failedLogs = join(dir, "failed-logs");
    await assert.rejects(
      exec(
        process.execPath,
        [
          join(root, "node_modules/@flue/cli/bin/flue.mjs"),
          "run",
          "probe",
          "--root",
          dir,
          "--target",
          "node",
          "--id",
          "failed-instance",
          "--input",
          '{"message":"PRIVATE_USER_PROMPT"}',
        ],
        {
          env: { PATH: process.env.PATH, HOME: dir, FLUE_LOG_DIR: failedLogs },
          timeout: 60_000,
        }
      )
    );
    const failedRecords = await readLedger(failedLogs);
    assert(failedRecords.some((event) => event.event === "turn" && event.failed));
    assert(failedRecords.some((event) => event.event === "telemetry_stop"));
    assert.equal(summarize(failedRecords).complete, false);
    for (const file of (await readdir(failedLogs)).filter((name) => name.endsWith(".jsonl"))) {
      assert.doesNotMatch(await readFile(join(failedLogs, file), "utf8"), /PRIVATE_/);
    }
  }
);

test("ledger detects lost and missing usage, counts compaction leaves once, and deduplicates imported events", async (t) => {
  const dir = await mkdtemp(join(tmpdir(), "flue-ledger-test-"));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const base = {
    schema: "flue.evlog.v1" as const,
    executionId: "exec",
    timestamp: "2026-10-21T00:00:00.000Z",
  };
  const usage = {
    input: 17,
    output: 3,
    cacheRead: 5,
    cacheWrite: 2,
    totalTokens: 27,
    cost: { input: 0.01, output: 0.02, cacheRead: 0.03, cacheWrite: 0.04, total: 0.1 },
  };
  const records: ObservationRecord[] = [
    { ...base, eventId: "1", sequence: 1, event: "telemetry_start" },
    {
      ...base,
      eventId: "2",
      sequence: 2,
      event: "turn_request",
      contextId: "context",
      turnId: "turn-a",
      purpose: "compaction",
    },
    {
      ...base,
      eventId: "3",
      sequence: 3,
      event: "turn",
      contextId: "context",
      turnId: "turn-a",
      purpose: "compaction",
      agent: "repair",
      model: "model-a",
      usage,
      usageStatus: "reported",
      costStatus: "estimated",
    },
    { ...base, eventId: "4", sequence: 4, event: "compaction", usage },
    { ...base, eventId: "5", sequence: 5, finalSequence: 5, event: "telemetry_stop" },
  ];
  await writeFile(
    join(dir, "a.jsonl"),
    records.map((record) => JSON.stringify(record)).join("\n") + "\n"
  );
  await copyFile(join(dir, "a.jsonl"), join(dir, "b.jsonl"));
  const report = summarize(await readLedger(dir));
  assert.equal(report.complete, true);
  assert.equal(report.turns, 1);
  assert.equal(report.groups[0].totalTokens, 27);
  assert.equal(report.groups[0].estimatedCostUsd, 0.1);
  assert.equal(summarize([...records].reverse()).complete, true);
  assert.equal(
    summarize([...records, { ...records[2], eventId: "duplicate-sequence" }]).complete,
    false
  );
  assert.equal(summarize(records.slice(0, -1)).complete, false);
  assert.equal(summarize(records.filter((record) => record.event !== "turn")).complete, false);
  assert.equal(
    summarize([
      ...records,
      ...records.slice(1, 3).map((record) => ({
        ...record,
        executionId: "other-exec",
        eventId: `other-${record.eventId}`,
      })),
    ]).complete,
    false
  );
  const unknown = summarize(
    records.map((record) =>
      record.event === "turn"
        ? { ...record, usage: undefined, usageStatus: "missing" as const }
        : record
    )
  );
  assert.equal(unknown.complete, false);
  assert.equal(unknown.groups[0].missingUsage, 1);
  const unknownCost = summarize(
    records.map((record) =>
      record.event === "turn"
        ? {
            ...record,
            costStatus: "unknown" as const,
            usage: {
              ...usage,
              cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
            },
          }
        : record
    )
  );
  assert.equal(unknownCost.complete, false);
  assert.equal(unknownCost.groups[0].totalTokens, 27);
  assert.equal(unknownCost.groups[0].estimatedCostUsd, null);
  await writeFile(
    join(dir, "b.jsonl"),
    JSON.stringify({ ...records[2], model: "conflicting-model" })
  );
  await assert.rejects(readLedger(dir), /conflicting event identity/);
  await writeFile(join(dir, "b.jsonl"), "{broken JSON\n");
  await assert.rejects(readLedger(dir));
  await writeFile(
    join(dir, "b.jsonl"),
    JSON.stringify({ ...records[2], usage: { ...usage, input: -1 } })
  );
  await assert.rejects(readLedger(dir), /invalid Flue ledger schema/);
});

test("persistence failures reject shutdown and cannot certify accounting", async (t) => {
  const dir = await mkdtemp(join(tmpdir(), "flue-drain-test-"));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const notDirectory = join(dir, "file");
  await writeFile(notDirectory, "not a directory");
  const telemetry = installFlueEvlog({
    service: "test",
    drain: ({ event }) => writeToFs(event, { dir: notDirectory, pretty: false }),
  });
  await assert.rejects(telemetry.dispose(), /drain failed/);
});

test("adapter preserves application logging policy and waits for buffered persistence", async () => {
  const application: string[] = [];
  initLogger({
    silent: true,
    env: { service: "host" },
    drain: ({ event }) => {
      application.push(String(event.service));
    },
  });
  const persisted: string[] = [];
  const buffered: string[] = [];
  const telemetry = installFlueEvlog({
    service: "accounting",
    drain: async ({ event }) => {
      await new Promise((resolve) => setTimeout(resolve, 5));
      buffered.push(String(event.event));
    },
    flush: async () => {
      persisted.push(...buffered.splice(0));
    },
  });
  createLogger({ event: "host-event" }).emit();
  await telemetry.dispose();
  assert.deepEqual(application, ["host"]);
  assert.deepEqual(persisted, ["telemetry_start", "telemetry_stop"]);

  const failed: string[] = [];
  const broken = installFlueEvlog({
    service: "accounting",
    drain: ({ event }) => {
      failed.push(String(event.event));
    },
    flush: async () => {
      throw new Error("fixture flush failure");
    },
  });
  await assert.rejects(broken.dispose(), /fixture flush failure/);
  assert.deepEqual(failed, ["telemetry_start"]);
});
