import { describe, expect, it } from "bun:test";
import { renderContextZoneStatus } from "../pi-dumb-zone/src/notifications";
import type { DumbZoneCheckResult } from "../pi-dumb-zone/src/checks";

function makeResult(partial: Partial<DumbZoneCheckResult>): DumbZoneCheckResult {
  return {
    inZone: false,
    utilization: 0,
    threshold: 40,
    compacted: false,
    details: "",
    ...partial,
  };
}

describe("dumb-zone status line", () => {
  it("renders smart zone bar without emojis", () => {
    const line = renderContextZoneStatus(makeResult({ utilization: 22 }));
    expect(line.startsWith("CZ ")).toBe(true);
    expect(line).toContain(" smart ");
    expect(line).toContain(" left");
    expect(line).toContain("|");
    expect(line).not.toContain("🧠");
    expect(line).not.toContain("⚠️");
    expect(line).not.toContain("🧟");
  });

  it("renders warm zone when utilization crosses warning threshold", () => {
    const line = renderContextZoneStatus(makeResult({ utilization: 42 }));
    expect(line).toContain(" warm ");
  });

  it("renders dumb zone when utilization crosses danger threshold", () => {
    const line = renderContextZoneStatus(makeResult({ utilization: 78, inZone: true }));
    expect(line).toContain(" dumb ");
  });

  it("marks pattern and compacted state in suffix", () => {
    const line = renderContextZoneStatus(
      makeResult({
        utilization: 30,
        compacted: true,
        inZone: true,
        violationType: "pattern",
      })
    );
    expect(line).toContain(" pattern");
    expect(line).toContain(" compacted");
  });
});
