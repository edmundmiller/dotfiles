import { describe, expect, it } from "bun:test";
import "../pi-dumb-zone/index.ts";
import {
  Text,
  visibleWidth,
} from "../pi-bash-live-view/node_modules/@mariozechner/pi-tui/dist/index.js";

describe("pi-tui overflow guard", () => {
  it("truncates overlong status text", () => {
    const text = new Text("", 1, 0);

    const longLine =
      "↳ ⏳ Retrying in 2s (attempt 1/3)... ⏳ Retrying in 4s (attempt 2/3)... ⚠️ Max retries (3) exhausted — trying fallback... 🔄 Primary model failed — switching to fallback: openai/gpt-5.4 via ope…";

    text.setText(longLine);

    const lines = text.render(194);

    expect(lines.length).toBeGreaterThan(0);
    for (const line of lines) {
      expect(visibleWidth(line)).toBeLessThanOrEqual(194);
    }
  });
});
