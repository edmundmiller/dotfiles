/**
 * Integration tests: pi-dumb-zone ↔ pi-dcp bridge
 *
 * Verifies the globalThis signal bridge between pi-dumb-zone (publisher)
 * and pi-dcp (consumer). Tests signal lifecycle and DCP nudge injection.
 *
 * Uses @marcfargas/pi-test-harness for real pi session testing.
 */

import { describe, it, expect, afterEach, beforeEach } from "bun:test";
import { createTestSession, when, says, type TestSession } from "@marcfargas/pi-test-harness";
import * as path from "node:path";

// Direct imports for signal manipulation
import {
  publishSignal,
  readSignal,
  clearSignal,
  type DumbZoneSignal,
} from "../pi-dumb-zone/src/signal";
import { readDumbZoneSignal } from "../pi-dcp/src/dumb-zone-bridge";

const DCP_EXTENSION = path.resolve(import.meta.dir, "../pi-dcp/index.ts");

const MOCK_TOOLS = {
  bash: "ok",
  read: "contents",
  write: "written",
  edit: "edited",
};

/** Extract text content from a message (handles string or content-array forms) */
function extractText(msg: any): string {
  if (typeof msg.content === "string") return msg.content;
  if (Array.isArray(msg.content)) {
    return msg.content.map((b: any) => b.text || "").join("");
  }
  return "";
}

/** Find last user message from a messages array */
function lastUserMessage(messages: any[]): any | undefined {
  return [...messages].reverse().find((m: any) => m.role === "user");
}

// ─── Signal bridge (unit-level) ──────────────────────────────────────────────

describe("signal bridge", () => {
  beforeEach(() => clearSignal());
  afterEach(() => clearSignal());

  it("publishSignal sets globalThis, readSignal reads it", () => {
    const signal: DumbZoneSignal = {
      inZone: true,
      utilization: 45,
      severity: "danger",
      compacted: false,
      timestamp: Date.now(),
    };
    publishSignal(signal);
    expect(readSignal()).toEqual(signal);
  });

  it("DCP bridge reads the same globalThis signal", () => {
    publishSignal({
      inZone: true,
      utilization: 55,
      severity: "critical",
      compacted: false,
      timestamp: Date.now(),
    });
    const bridgeSignal = readDumbZoneSignal();
    expect(bridgeSignal).toBeDefined();
    expect(bridgeSignal!.severity).toBe("critical");
    expect(bridgeSignal!.utilization).toBe(55);
  });

  it("clearSignal removes signal for both readers", () => {
    publishSignal({
      inZone: true,
      utilization: 40,
      severity: "danger",
      compacted: false,
      timestamp: Date.now(),
    });
    expect(readSignal()).toBeDefined();
    expect(readDumbZoneSignal()).toBeDefined();

    clearSignal();

    expect(readSignal()).toBeUndefined();
    expect(readDumbZoneSignal()).toBeUndefined();
  });

  it("severity levels are preserved through the bridge", () => {
    for (const severity of ["warning", "danger", "critical"] as const) {
      publishSignal({
        inZone: true,
        utilization: 30,
        severity,
        compacted: false,
        timestamp: Date.now(),
      });
      expect(readDumbZoneSignal()!.severity).toBe(severity);
    }
  });
});

// ─── DCP nudge injection (integration with test harness) ─────────────────────
//
// Key: signal must be set BEFORE t.run() because pi fires the `context` event
// before `agent_start`. DCP reads the signal during `context`.
//
// We capture the injected content via a factory extension's context handler,
// which runs AFTER DCP's handler and sees the chained messages.

describe("DCP dumb-zone nudge injection", () => {
  let t: TestSession;

  beforeEach(() => clearSignal());
  afterEach(() => {
    clearSignal();
    t?.dispose();
  });

  it("injects critical nudge at danger severity (≥40%)", async () => {
    let capturedMessages: any[] = [];

    t = await createTestSession({
      extensions: [DCP_EXTENSION],
      extensionFactories: [
        (pi: any) => {
          pi.on("context", async (event: any) => {
            capturedMessages = JSON.parse(JSON.stringify(event.messages));
          });
        },
      ],
      mockTools: MOCK_TOOLS,
    });

    // Set danger signal before run
    publishSignal({
      inZone: true,
      utilization: 42,
      severity: "danger",
      compacted: false,
      timestamp: Date.now(),
    });

    await t.run(when("Do something", [says("Done.")]));

    const lastUser = lastUserMessage(capturedMessages);
    expect(lastUser).toBeDefined();

    const text = extractText(lastUser);
    expect(text).toContain("dcp-nudge");
    expect(text).toContain('priority="critical"');
    expect(text).toContain("42%");
    expect(text).toContain("dumb zone");
  });

  it("injects nudge at critical severity with correct pct substitution", async () => {
    let capturedMessages: any[] = [];

    t = await createTestSession({
      extensions: [DCP_EXTENSION],
      extensionFactories: [
        (pi: any) => {
          pi.on("context", async (event: any) => {
            capturedMessages = JSON.parse(JSON.stringify(event.messages));
          });
        },
      ],
      mockTools: MOCK_TOOLS,
    });

    publishSignal({
      inZone: true,
      utilization: 65.7,
      severity: "critical",
      compacted: true,
      timestamp: Date.now(),
    });

    await t.run(when("Test", [says("Done.")]));

    const lastUser = lastUserMessage(capturedMessages);
    const text = extractText(lastUser);
    // 65.7.toFixed(0) = "66"
    expect(text).toContain("66%");
    expect(text).toContain("dumb zone");
  });

  it("does NOT inject dumb-zone nudge at warning severity (<40%)", async () => {
    let capturedMessages: any[] = [];

    t = await createTestSession({
      extensions: [DCP_EXTENSION],
      extensionFactories: [
        (pi: any) => {
          pi.on("context", async (event: any) => {
            capturedMessages = JSON.parse(JSON.stringify(event.messages));
          });
        },
      ],
      mockTools: MOCK_TOOLS,
    });

    publishSignal({
      inZone: true,
      utilization: 32,
      severity: "warning",
      compacted: false,
      timestamp: Date.now(),
    });

    await t.run(when("Test", [says("Done.")]));

    const lastUser = lastUserMessage(capturedMessages);
    expect(lastUser).toBeDefined();

    const text = extractText(lastUser);
    // Warning severity should not trigger dumb-zone nudge
    expect(text).not.toContain("dumb zone");
    expect(text).not.toContain('priority="critical"');
  });

  it("no signal = no dumb-zone nudge (DCP standalone)", async () => {
    let capturedMessages: any[] = [];

    t = await createTestSession({
      extensions: [DCP_EXTENSION],
      extensionFactories: [
        (pi: any) => {
          pi.on("context", async (event: any) => {
            capturedMessages = JSON.parse(JSON.stringify(event.messages));
          });
        },
      ],
      mockTools: MOCK_TOOLS,
    });

    // No signal set — clearSignal() already called in beforeEach

    await t.run(when("Test", [says("Done.")]));

    const lastUser = lastUserMessage(capturedMessages);
    expect(lastUser).toBeDefined();

    const text = extractText(lastUser);
    expect(text).not.toContain("dumb zone");
    expect(text).not.toContain('priority="critical"');
  });

  it("signal with inZone=false does not trigger nudge", async () => {
    let capturedMessages: any[] = [];

    t = await createTestSession({
      extensions: [DCP_EXTENSION],
      extensionFactories: [
        (pi: any) => {
          pi.on("context", async (event: any) => {
            capturedMessages = JSON.parse(JSON.stringify(event.messages));
          });
        },
      ],
      mockTools: MOCK_TOOLS,
    });

    publishSignal({
      inZone: false,
      utilization: 25,
      severity: "warning",
      compacted: false,
      timestamp: Date.now(),
    });

    await t.run(when("Test", [says("Done.")]));

    const lastUser = lastUserMessage(capturedMessages);
    expect(lastUser).toBeDefined();

    const text = extractText(lastUser);
    expect(text).not.toContain("dumb zone");
  });

  it("dumb-zone nudge takes priority over periodic nudge", async () => {
    let capturedMessages: any[] = [];

    t = await createTestSession({
      extensions: [DCP_EXTENSION],
      extensionFactories: [
        (pi: any) => {
          pi.on("context", async (event: any) => {
            capturedMessages = JSON.parse(JSON.stringify(event.messages));
          });
        },
      ],
      mockTools: MOCK_TOOLS,
    });

    publishSignal({
      inZone: true,
      utilization: 50,
      severity: "critical",
      compacted: false,
      timestamp: Date.now(),
    });

    await t.run(when("Test", [says("Done.")]));

    const lastUser = lastUserMessage(capturedMessages);
    const text = extractText(lastUser);

    // Should have dumb-zone nudge (priority=critical), not generic periodic nudge
    expect(text).toContain("dumb zone");
    expect(text).toContain('priority="critical"');
    // Should NOT have the generic periodic nudge text
    expect(text).not.toContain("Consider reviewing the <prunable-tools>");
  });
});
