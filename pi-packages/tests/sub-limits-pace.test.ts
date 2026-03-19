import { afterEach, describe, expect, it } from "bun:test";
import { createTestSession, when, type TestSession } from "@marcfargas/pi-test-harness";
import * as path from "node:path";

const SUB_LIMITS = "/Users/emiller/.pi/agent/extensions/sub-limits.ts";
const MOCK_SUB_CORE = path.resolve(import.meta.dir, "fixtures/mock-sub-core.ts");

const EMIT_USAGE_EXTENSION = (pi: any): void => {
  const usage = {
    provider: "codex",
    displayName: "OpenAI Codex",
    windows: [
      {
        label: "Week",
        usedPercent: 42,
        resetAt: new Date(Date.now() + 6 * 24 * 60 * 60 * 1000).toISOString(),
      },
    ],
  };

  pi.registerCommand("emit-usage", {
    description: "Emit a mock sub-core:ready update",
    handler: async () => {
      pi.events.emit("sub-core:ready", { state: { usage } });
    },
  });
};

function notifyTexts(t: TestSession): string[] {
  return t.events
    .uiCallsFor("notify")
    .map((call) => (typeof call.args[0] === "string" ? call.args[0] : String(call.args[0] ?? "")));
}

function paceStatusTextCount(t: TestSession): number {
  return t.events
    .uiCallsFor("setStatus")
    .filter(
      (call) =>
        call.args[0] === "sub-pace" &&
        typeof call.args[1] === "string" &&
        call.args[1].includes("Pace")
    ).length;
}

describe("sub-limits pace harness", () => {
  let t: TestSession;

  afterEach(() => t?.dispose());

  it("/sub-pace returns a detailed pace message", async () => {
    t = await createTestSession({
      extensions: [MOCK_SUB_CORE, SUB_LIMITS],
    });

    await t.run(when("/sub-pace", []));

    const texts = notifyTexts(t).join("\n");
    expect(texts).toContain("Pace:");
    expect(texts).toContain("Expected by now:");
    expect(texts).toContain("Actual now:");
  });

  it("writes footer pace status via setStatus", async () => {
    t = await createTestSession({
      extensions: [MOCK_SUB_CORE, SUB_LIMITS],
    });

    await t.run(when("hello", []));

    const statusCalls = t.events.uiCallsFor("setStatus");
    const paceCalls = statusCalls.filter((call) => call.args[0] === "sub-pace");

    expect(paceCalls.length).toBeGreaterThan(0);
    const hasPaceText = paceCalls.some(
      (call) => typeof call.args[1] === "string" && call.args[1].includes("Pace")
    );
    expect(hasPaceText).toBe(true);
  });

  it("does not duplicate pace updates across /reload", async () => {
    t = await createTestSession({
      extensions: [SUB_LIMITS],
      extensionFactories: [EMIT_USAGE_EXTENSION],
    });

    let priorCount = paceStatusTextCount(t);

    for (let i = 0; i < 4; i += 1) {
      await t.run(when("/emit-usage", []));
      const nextCount = paceStatusTextCount(t);
      expect(nextCount - priorCount).toBe(1);
      priorCount = nextCount;
      await t.run(when("/reload", []));
    }
  });

  it("/sub-pace:toggle clears footer status", async () => {
    t = await createTestSession({
      extensions: [MOCK_SUB_CORE, SUB_LIMITS],
    });

    await t.run(when("/sub-pace:toggle", []));

    const statusCalls = t.events.uiCallsFor("setStatus");
    const turnedOff = statusCalls.some(
      (call) => call.args[0] === "sub-pace" && call.args[1] === ""
    );
    expect(turnedOff).toBe(true);
  });
});
