import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

type StyleMode = "default" | "rgb" | "palette";

type CellStyle = {
  bold: boolean;
  dim: boolean;
  italic: boolean;
  underline: boolean;
  inverse: boolean;
  invisible: boolean;
  strikethrough: boolean;
  fgMode: StyleMode;
  fg: number;
  bgMode: StyleMode;
  bg: number;
};

type SnapshotCell = {
  ch: string;
  style: CellStyle;
};

type SnapshotLine = SnapshotCell[];
export type TerminalSnapshot = SnapshotLine[];

type TerminalUpdatePayload = {
  elapsedMs: number;
  snapshot: TerminalSnapshot;
  inAltScreen: boolean;
  inSyncRender: boolean;
};

type XtermCellLike = {
  isBold?: () => boolean;
  isDim?: () => boolean;
  isItalic?: () => boolean;
  isUnderline?: () => boolean;
  isInverse?: () => boolean;
  isInvisible?: () => boolean;
  isStrikethrough?: () => boolean;
  isFgDefault?: () => boolean;
  isFgRGB?: () => boolean;
  isFgPalette?: () => boolean;
  isBgDefault?: () => boolean;
  isBgRGB?: () => boolean;
  isBgPalette?: () => boolean;
  getFgColor?: () => number;
  getBgColor?: () => number;
  getWidth: () => number;
  getChars: () => string;
};

type XtermBufferLineLike = {
  isWrapped?: boolean;
  translateToString: (trimRight?: boolean) => string;
  getCell: (x: number, cell?: XtermCellLike) => XtermCellLike | undefined;
};

type XtermBufferLike = {
  baseY: number;
  length: number;
  getLine: (y: number) => XtermBufferLineLike | undefined;
  getNullCell: () => XtermCellLike;
};

type XtermTerminalLike = {
  rows: number;
  cols: number;
  buffer: {
    active: XtermBufferLike;
    normal: XtermBufferLike;
  };
  write: (data: string, callback: () => void) => void;
  dispose?: () => void;
};

type XtermTerminalCtor = new (options: {
  cols: number;
  rows: number;
  scrollback: number;
  allowProposedApi: boolean;
  convertEol: boolean;
}) => XtermTerminalLike;

let TerminalCtor: XtermTerminalCtor | null = null;

function ensureXtermHeadlessLoaded(): XtermTerminalCtor {
  if (!globalThis.window) {
    (globalThis as typeof globalThis & { window: object }).window = {};
  }
  if (!TerminalCtor) {
    ({ Terminal: TerminalCtor } = require("@xterm/headless") as { Terminal: XtermTerminalCtor });
  }
  return TerminalCtor;
}

function defaultStyle(): CellStyle {
  return {
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
}

function cloneStyle(style: CellStyle): CellStyle {
  return {
    bold: style.bold,
    dim: style.dim,
    italic: style.italic,
    underline: style.underline,
    inverse: style.inverse,
    invisible: style.invisible,
    strikethrough: style.strikethrough,
    fgMode: style.fgMode,
    fg: style.fg,
    bgMode: style.bgMode,
    bg: style.bg,
  };
}

function cloneSnapshot(snapshot: TerminalSnapshot): TerminalSnapshot {
  return snapshot.map((line) =>
    line.map((cell) => ({ ...cell, style: cloneStyle(cell.style ?? defaultStyle()) }))
  );
}

function styleKey(style: CellStyle): string {
  return [
    style.bold ? "b" : "-",
    style.dim ? "d" : "-",
    style.italic ? "i" : "-",
    style.underline ? "u" : "-",
    style.inverse ? "v" : "-",
    style.invisible ? "x" : "-",
    style.strikethrough ? "s" : "-",
    `fg:${style.fgMode}:${style.fg}`,
    `bg:${style.bgMode}:${style.bg}`,
  ].join("");
}

function rgbToSgr(isForeground: boolean, value: number): string {
  const r = (value >> 16) & 255;
  const g = (value >> 8) & 255;
  const b = value & 255;
  return isForeground ? `38;2;${r};${g};${b}` : `48;2;${r};${g};${b}`;
}

function paletteToSgr(isForeground: boolean, index: number): string {
  return isForeground ? `38;5;${index}` : `48;5;${index}`;
}

function styleToAnsi(style: CellStyle): string {
  const codes = ["0"];
  if (style.bold) codes.push("1");
  if (style.dim) codes.push("2");
  if (style.italic) codes.push("3");
  if (style.underline) codes.push("4");
  if (style.inverse) codes.push("7");
  if (style.invisible) codes.push("8");
  if (style.strikethrough) codes.push("9");
  if (style.fgMode === "rgb") codes.push(rgbToSgr(true, style.fg));
  else if (style.fgMode === "palette") codes.push(paletteToSgr(true, style.fg));
  if (style.bgMode === "rgb") codes.push(rgbToSgr(false, style.bg));
  else if (style.bgMode === "palette") codes.push(paletteToSgr(false, style.bg));
  return `\x1b[${codes.join(";")}m`;
}

export function snapshotToAnsiContentLines(snapshot: TerminalSnapshot): string[] {
  return snapshot.map((line) => {
    let out = "";
    let current = defaultStyle();
    let currentKey = styleKey(current);
    for (const cell of line) {
      const style = cell.style ?? defaultStyle();
      const nextKey = styleKey(style);
      if (nextKey !== currentKey) {
        out += styleToAnsi(style);
        current = cloneStyle(style);
        currentKey = nextKey;
      }
      out += cell.ch;
    }
    return `${out}\x1b[0m`.replace(/\s+\x1b\[0m$/, "\x1b[0m");
  });
}

function sanitizeOutput(text: string): string {
  return text
    .replace(/\r/g, "")
    .replace(/\u0000/g, "")
    .replace(/\p{Cf}/gu, "");
}

function extractTextFromBuffer(buffer: XtermBufferLike): string {
  const logicalLines: string[] = [];

  for (let i = 0; i < buffer.length; i += 1) {
    const line = buffer.getLine(i);
    const text = sanitizeOutput(line?.translateToString(true) ?? "");
    if (line?.isWrapped && logicalLines.length > 0) {
      logicalLines[logicalLines.length - 1] += text;
    } else {
      logicalLines.push(text);
    }
  }

  while (logicalLines.length > 0 && logicalLines[logicalLines.length - 1] === "") {
    logicalLines.pop();
  }

  const text = logicalLines.join("\n").trimEnd();
  return text.length === 0 ? "(no output)" : `${text}\n`;
}

function normalizePaletteColor(mode: StyleMode, value: number): { mode: StyleMode; value: number } {
  if (mode !== "palette") return { mode, value };
  if (value < 0 || value > 255) {
    return { mode: "default", value: 0 };
  }
  return { mode: "palette", value };
}

function styleFromCell(cell: XtermCellLike | undefined): CellStyle {
  const rawFgMode: StyleMode = cell?.isFgDefault?.()
    ? "default"
    : cell?.isFgRGB?.()
      ? "rgb"
      : cell?.isFgPalette?.()
        ? "palette"
        : "default";
  const rawBgMode: StyleMode = cell?.isBgDefault?.()
    ? "default"
    : cell?.isBgRGB?.()
      ? "rgb"
      : cell?.isBgPalette?.()
        ? "palette"
        : "default";

  const fg = normalizePaletteColor(rawFgMode, cell?.getFgColor?.() ?? 0);
  const bg = normalizePaletteColor(rawBgMode, cell?.getBgColor?.() ?? 0);

  return {
    bold: Boolean(cell?.isBold?.()),
    dim: Boolean(cell?.isDim?.()),
    italic: Boolean(cell?.isItalic?.()),
    underline: Boolean(cell?.isUnderline?.()),
    inverse: Boolean(cell?.isInverse?.()),
    invisible: Boolean(cell?.isInvisible?.()),
    strikethrough: Boolean(cell?.isStrikethrough?.()),
    fgMode: fg.mode,
    fg: fg.value,
    bgMode: bg.mode,
    bg: bg.value,
  };
}

function createXterm(cols: number, rows: number, scrollback: number): XtermTerminalLike {
  const Terminal = ensureXtermHeadlessLoaded();
  return new Terminal({
    cols,
    rows,
    scrollback,
    allowProposedApi: true,
    convertEol: true,
  });
}

function snapshotTerminal(term: XtermTerminalLike): TerminalSnapshot {
  const buffer = term.buffer.active;
  const start = buffer.baseY;
  const lines: TerminalSnapshot = [];
  const scratchCell = buffer.getNullCell();
  for (let y = 0; y < term.rows; y++) {
    const row: SnapshotLine = [];
    const line = buffer.getLine(start + y);
    for (let x = 0; x < term.cols; x++) {
      const cell = line?.getCell(x, scratchCell);
      if (!cell) {
        row.push({ ch: " ", style: defaultStyle() });
        continue;
      }
      if (cell.getWidth() === 0) continue;
      row.push({
        ch: cell.getChars() || " ",
        style: styleFromCell(cell),
      });
    }
    lines.push(row);
  }
  return lines;
}

function createDecPrivateModeTracker(onModeChange: (mode: number, enabled: boolean) => void) {
  let state: "ground" | "escape" | "csi" = "ground";
  let privateMarker = false;
  let params = "";

  function reset() {
    state = "ground";
    privateMarker = false;
    params = "";
  }

  function finalize(finalByte: string) {
    if (!privateMarker || (finalByte !== "h" && finalByte !== "l")) {
      reset();
      return;
    }
    const enabled = finalByte === "h";
    for (const part of params.split(";")) {
      if (!part) continue;
      const mode = Number(part);
      if (!Number.isInteger(mode)) continue;
      onModeChange(mode, enabled);
    }
    reset();
  }

  return {
    push(text: string) {
      for (const ch of text) {
        if (state === "ground") {
          if (ch === "\x1b") state = "escape";
          continue;
        }
        if (state === "escape") {
          if (ch === "[") {
            state = "csi";
            privateMarker = false;
            params = "";
            continue;
          }
          state = ch === "\x1b" ? "escape" : "ground";
          continue;
        }
        if (state === "csi") {
          if (ch === "?") {
            if (params.length === 0 && !privateMarker) {
              privateMarker = true;
              continue;
            }
            reset();
            continue;
          }
          if ((ch >= "0" && ch <= "9") || ch === ";") {
            params += ch;
            continue;
          }
          if (ch >= "@" && ch <= "~") {
            finalize(ch);
            continue;
          }
          reset();
        }
      }
    },
  };
}

export function createTerminalEmulator({
  cols,
  rows,
  scrollback = 10_000,
}: {
  cols: number;
  rows: number;
  scrollback?: number;
}) {
  const term = createXterm(cols, rows, scrollback);
  const listeners = new Set<(payload: TerminalUpdatePayload) => void>();
  let writeChain: Promise<void | TerminalUpdatePayload> = Promise.resolve();
  let inAltScreen = false;
  let inSyncRender = false;
  let lastCompletedSnapshot = snapshotTerminal(term);
  let latestSnapshot = cloneSnapshot(lastCompletedSnapshot);
  let lastElapsedMs = 0;
  const modeTracker = createDecPrivateModeTracker((mode, enabled) => {
    if (mode === 2026) {
      inSyncRender = enabled;
      return;
    }
    if (mode === 1049 || mode === 1047 || mode === 47) {
      inAltScreen = enabled;
    }
  });

  function emitUpdate(payload: TerminalUpdatePayload) {
    for (const listener of listeners) listener(payload);
  }

  async function consumeProcessStdout(
    chunk: string,
    { elapsedMs = lastElapsedMs }: { elapsedMs?: number } = {}
  ) {
    lastElapsedMs = elapsedMs;
    modeTracker.push(chunk);
    writeChain = writeChain.then(
      () =>
        new Promise<TerminalUpdatePayload>((resolve) => {
          term.write(chunk, () => {
            latestSnapshot = snapshotTerminal(term);
            const renderableSnapshot = inSyncRender ? lastCompletedSnapshot : latestSnapshot;
            if (!inSyncRender) lastCompletedSnapshot = cloneSnapshot(latestSnapshot);
            const payload: TerminalUpdatePayload = {
              elapsedMs: lastElapsedMs,
              snapshot: cloneSnapshot(renderableSnapshot),
              inAltScreen,
              inSyncRender,
            };
            emitUpdate(payload);
            resolve(payload);
          });
        })
    );
    return writeChain;
  }

  function getViewportSnapshot(): TerminalSnapshot {
    return cloneSnapshot(inSyncRender ? lastCompletedSnapshot : latestSnapshot);
  }

  function getStrippedTextIncludingEntireScrollback(): string {
    return extractTextFromBuffer(term.buffer.normal);
  }

  return {
    cols,
    rows,
    consumeProcessStdout,
    whenIdle() {
      return writeChain.then(() => undefined);
    },
    subscribe(listener: (payload: TerminalUpdatePayload) => void) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    getState() {
      return { inAltScreen, inSyncRender, elapsedMs: lastElapsedMs };
    },
    getViewportSnapshot,
    getStrippedTextIncludingEntireScrollback,
    dispose() {
      term.dispose?.();
      listeners.clear();
    },
  };
}
