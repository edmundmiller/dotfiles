import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

test(
  "bundled TinyFix corrects prose and preserves protected text",
  { timeout: 30000 },
  async () => {
    const worker = spawn(
      process.execPath,
      [
        fileURLToPath(new URL("./tinyfix-worker.mjs", import.meta.url)),
        fileURLToPath(new URL("./.models", import.meta.url)),
      ],
      { stdio: ["pipe", "pipe", "pipe"] }
    );
    const lines = createInterface({ input: worker.stdout })[Symbol.asyncIterator]();
    let stderr = "";
    worker.stderr.on("data", (data) => {
      stderr += data;
    });
    const exited = new Promise((resolve) => worker.on("exit", resolve));
    const reply = async () => {
      const line = await lines.next();
      assert.equal(line.done, false, "worker must reply before EOF");
      return JSON.parse(line.value);
    };
    const request = (value) => {
      worker.stdin.write(`${JSON.stringify(value)}\n`);
      return reply();
    };
    try {
      assert.deepEqual(await reply(), { ready: true });
      const result = await request({
        op: "check",
        text: "I got a letter form the bank and did not recieve it.",
      });
      assert.equal(result.text, "I got a letter from the bank and did not receive it.");
      assert.deepEqual(
        result.fixes.map(({ original, replacement, kind }) => ({ original, replacement, kind })),
        [
          { original: "form", replacement: "from", kind: "context" },
          { original: "recieve", replacement: "receive", kind: "spelling" },
        ]
      );
      const correct = await request({
        op: "check",
        text: "Please fill out the form for the bank.",
      });
      assert.deepEqual(correct.fixes, []);
      const protectedText =
        "`recieve` https://example.com/recieve person@recieve.com\n```js\nconst recieve = 1;\n```";
      assert.equal((await request({ op: "check", text: protectedText })).text, protectedText);
      const ranged = await request({
        op: "check",
        text: "🦀 recieve and recieve",
        range: [15, 22],
      });
      assert.equal(ranged.text, "🦀 recieve and receive");
      assert.equal(ranged.fixes[0].from, 15);
      const beforeCaret = await request({
        op: "check",
        text: "🦀 recieve and recieve",
        range: [3, 11],
      });
      assert.equal(beforeCaret.text, "🦀 receive and recieve");
      assert.deepEqual(await request({ op: "ignore", word: "recieve" }), {});
      assert.deepEqual((await request({ op: "check", text: "I did not recieve it." })).fixes, []);
      assert.deepEqual(await request({ op: "check", text: "secret".repeat(3000) }), {
        error: "TinyType could not check this text",
      });
      worker.stdin.write("not JSON\n");
      assert.deepEqual(await reply(), { error: "TinyType could not check this text" });
      assert.deepEqual((await request({ op: "check", text: "This is fine." })).fixes, []);
      worker.stdin.end();
      assert.equal(await exited, 0);
      assert.equal(stderr, "");
    } finally {
      worker.kill();
    }
  }
);
