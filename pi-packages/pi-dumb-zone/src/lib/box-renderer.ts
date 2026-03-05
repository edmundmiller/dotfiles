/**
 * Minimal box renderer for overlay borders.
 * Extracted from @aliou/tui-utils for the-dumb-zone overlay.
 */

import type { Theme } from "@mariozechner/pi-coding-agent";
import { visibleWidth } from "@mariozechner/pi-tui";

export type BoxRenderer = {
  top: () => string;
  bottom: () => string;
  row: (content: string) => string;
  centeredRow: (content: string) => string;
  empty: () => string;
  innerWidth: number;
};

export function createThemedBoxRenderer(width: number, theme: Theme): BoxRenderer {
  const borderFn = (s: string) => theme.fg("border", s);
  const innerWidth = Math.max(0, width - 3);
  const borderWidth = width - 2;

  const pad = (s: string, w: number): string => {
    const vis = visibleWidth(s);
    return s + " ".repeat(Math.max(0, w - vis));
  };

  return {
    innerWidth,

    top: () => borderFn(`╭${"─".repeat(Math.max(0, borderWidth))}╮`),

    bottom: () => borderFn(`╰${"─".repeat(Math.max(0, borderWidth))}╯`),

    row: (content: string): string =>
      `${borderFn("│")} ${pad(content, innerWidth)}${borderFn("│")}`,

    centeredRow: (content: string): string => {
      const contentLen = visibleWidth(content);
      const availableSpace = innerWidth + 1;
      const totalPadding = Math.max(0, availableSpace - contentLen);
      const leftPad = Math.floor(totalPadding / 2);
      const rightPad = totalPadding - leftPad;
      return borderFn("│") + " ".repeat(leftPad) + content + " ".repeat(rightPad) + borderFn("│");
    },

    empty: (): string => `${borderFn("│")} ${" ".repeat(innerWidth)}${borderFn("│")}`,
  };
}
