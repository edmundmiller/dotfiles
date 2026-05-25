import test from "node:test";
import assert from "node:assert/strict";
import { visibleWidth } from "@mariozechner/pi-tui";
import { buildWidgetAnsiLines } from "../widget.ts";

const defaultStyle = {
  bold: false,
  dim: false,
  italic: false,
  underline: false,
  inverse: false,
  invisible: false,
  strikethrough: false,
  fgMode: "default",
  fg: 0,
  bgMode: "default",
  bg: 0,
};

test("widget lines never exceed requested width with wide glyphs", () => {
  const width = 122;
  const innerWidth = width - 2;
  const row = [
    { ch: "⭐", style: defaultStyle },
    ..."a"
      .repeat(innerWidth - 1)
      .split("")
      .map((ch) => ({ ch, style: defaultStyle })),
  ];

  const lines = buildWidgetAnsiLines({
    snapshot: [row],
    width,
    rows: 1,
    elapsedMs: 0,
  });

  for (const line of lines) {
    assert.ok(visibleWidth(line) <= width, `line exceeded width: ${visibleWidth(line)} > ${width}`);
  }

  assert.equal(visibleWidth(lines[1]), width);
});
