/**
 * review-screen.ts - full-screen Pi-native diff review cockpit.
 */

import { renderDiff, type Theme } from "@mariozechner/pi-coding-agent";
import {
  Key,
  matchesKey,
  truncateToWidth,
  type Component,
  type TUI,
  visibleWidth,
  wrapTextWithAnsi,
} from "@mariozechner/pi-tui";
import path from "node:path";
import type { ReviewData, ReviewFile } from "./review-git";

export type ReviewPane = "files" | "diff" | "meta";

export interface ReviewScreenSnapshot {
  selectedFileIndex: number;
  selectedFilePath?: string;
  focusPane: ReviewPane;
  diffScroll: number;
  metaScroll: number;
  currentHunkIndex: number;
}

export type ReviewScreenResult =
  | {
      action: "close";
      snapshot: ReviewScreenSnapshot;
    }
  | {
      action: "open-file";
      snapshot: ReviewScreenSnapshot;
      filePath: string;
      line: number;
    };

interface PreparedDiff {
  lines: string[];
  hunkStartLines: number[];
}

type ReviewLayout =
  | {
      kind: "wide";
      filesWidth: number;
      diffWidth: number;
      metaWidth: number;
      height: number;
    }
  | {
      kind: "split";
      filesWidth: number;
      diffWidth: number;
      topHeight: number;
      metaHeight: number;
      height: number;
    }
  | {
      kind: "stacked";
      filesHeight: number;
      diffHeight: number;
      metaHeight: number;
      height: number;
    };

function clamp(value: number, min: number, max: number): number {
  if (max < min) return min;
  return Math.min(max, Math.max(min, value));
}

function sliceWindow(
  lines: string[],
  scroll: number,
  size: number
): { lines: string[]; scroll: number } {
  const maxScroll = Math.max(0, lines.length - size);
  const nextScroll = clamp(scroll, 0, maxScroll);
  return {
    lines: lines.slice(nextScroll, nextScroll + size),
    scroll: nextScroll,
  };
}

function centerWindow(total: number, selected: number, size: number): number {
  const maxStart = Math.max(0, total - size);
  return clamp(selected - Math.floor(size / 2), 0, maxStart);
}

export function ellipsizePath(input: string, maxWidth: number): string {
  if (maxWidth <= 0) return "";
  if (visibleWidth(input) <= maxWidth) return input;

  const parts = input.split("/").filter(Boolean);
  const leaf = parts[parts.length - 1] ?? input;
  const leafOnly = `…/${leaf}`;
  if (visibleWidth(leafOnly) <= maxWidth) return leafOnly;

  if (parts.length >= 2) {
    const tail = `${parts[parts.length - 2]}/${leaf}`;
    const collapsed = `…/${tail}`;
    if (visibleWidth(collapsed) <= maxWidth) return collapsed;
  }

  return truncateToWidth(input, maxWidth);
}

export function resolveReviewLayout(width: number, height: number): ReviewLayout {
  const safeHeight = Math.max(3, height);

  if (width >= 140) {
    const filesWidth = Math.min(34, Math.max(26, Math.floor(width * 0.22)));
    const metaWidth = Math.min(34, Math.max(24, Math.floor(width * 0.22)));
    const diffWidth = width - filesWidth - metaWidth - 2;
    if (diffWidth >= 52) {
      return {
        kind: "wide",
        filesWidth,
        diffWidth,
        metaWidth,
        height: safeHeight,
      };
    }
  }

  const preferredMetaHeight = Math.min(10, Math.max(7, Math.floor(safeHeight * 0.26)));
  const splitFilesWidth = Math.min(30, Math.max(24, Math.floor(width * 0.27)));
  const splitDiffWidth = width - splitFilesWidth - 1;
  const splitTopHeight = safeHeight - preferredMetaHeight;
  if (width >= 100 && splitDiffWidth >= 40 && splitTopHeight >= 9) {
    return {
      kind: "split",
      filesWidth: splitFilesWidth,
      diffWidth: splitDiffWidth,
      topHeight: splitTopHeight,
      metaHeight: preferredMetaHeight,
      height: safeHeight,
    };
  }

  let filesHeight = Math.min(8, Math.max(5, Math.floor(safeHeight * 0.22)));
  let metaHeight = Math.min(8, Math.max(5, Math.floor(safeHeight * 0.24)));
  let diffHeight = safeHeight - filesHeight - metaHeight;

  if (diffHeight < 6) {
    const deficit = 6 - diffHeight;
    const reduceMeta = Math.min(deficit, Math.max(0, metaHeight - 5));
    metaHeight -= reduceMeta;
    diffHeight += reduceMeta;
  }

  if (diffHeight < 6) {
    const deficit = 6 - diffHeight;
    const reduceFiles = Math.min(deficit, Math.max(0, filesHeight - 5));
    filesHeight -= reduceFiles;
    diffHeight += reduceFiles;
  }

  diffHeight = safeHeight - filesHeight - metaHeight;

  return {
    kind: "stacked",
    filesHeight,
    diffHeight,
    metaHeight,
    height: safeHeight,
  };
}

function statusColor(theme: Theme, status: string): string {
  if (status.includes("?")) return theme.fg("warning", status);
  if (status.includes("D")) return theme.fg("error", status);
  if (status.includes("A")) return theme.fg("success", status);
  if (status.includes("R")) return theme.fg("accent", status);
  if (status.includes("U")) return theme.fg("warning", status);
  return theme.fg("accent", status);
}

export class ReviewScreen implements Component {
  private selectedFileIndex = 0;
  private focusPane: ReviewPane = "files";
  private diffScroll = 0;
  private metaScroll = 0;
  private currentHunkIndex = 0;
  private notice?: string;

  private cachedWidth?: number;
  private cachedState?: string;
  private cachedLines?: string[];

  private cachedDiffKey?: string;
  private cachedDiff?: PreparedDiff;

  private lastDiffInnerWidth = 48;
  private lastDiffInnerHeight = 10;
  private lastMetaInnerWidth = 24;
  private lastMetaInnerHeight = 8;

  constructor(
    private tui: TUI,
    private theme: Theme,
    private data: ReviewData,
    private done: (result: ReviewScreenResult) => void,
    snapshot?: ReviewScreenSnapshot
  ) {
    if (!snapshot) return;

    const matchedIndex =
      snapshot.selectedFilePath === undefined
        ? -1
        : this.data.files.findIndex((file) => file.path === snapshot.selectedFilePath);
    const fallbackIndex = clamp(
      snapshot.selectedFileIndex,
      0,
      Math.max(0, this.data.files.length - 1)
    );

    this.selectedFileIndex = matchedIndex === -1 ? fallbackIndex : matchedIndex;
    this.focusPane = snapshot.focusPane;
    this.diffScroll = Math.max(0, snapshot.diffScroll);
    this.metaScroll = Math.max(0, snapshot.metaScroll);
    this.currentHunkIndex = Math.max(0, snapshot.currentHunkIndex);
  }

  invalidate(): void {
    this.cachedWidth = undefined;
    this.cachedState = undefined;
    this.cachedLines = undefined;
    this.cachedDiffKey = undefined;
    this.cachedDiff = undefined;
  }

  handleInput(data: string): void {
    if (matchesKey(data, Key.escape) || matchesKey(data, "q")) {
      this.done({ action: "close", snapshot: this.snapshot() });
      return;
    }

    if (matchesKey(data, Key.tab)) {
      this.switchPane(1);
      return;
    }

    if (matchesKey(data, Key.shift("tab"))) {
      this.switchPane(-1);
      return;
    }

    if (matchesKey(data, Key.enter)) {
      const file = this.selectedFile();
      if (!file) return;
      if (!file.openable) {
        this.showNotice("selected file is deleted or missing on disk");
        return;
      }
      this.done({
        action: "open-file",
        snapshot: this.snapshot(),
        filePath: file.absolutePath,
        line: this.getOpenLine(),
      });
      return;
    }

    if (matchesKey(data, "n")) {
      this.jumpHunk(1);
      return;
    }

    if (matchesKey(data, "p")) {
      this.jumpHunk(-1);
      return;
    }

    if (matchesKey(data, Key.pageDown)) {
      this.page(1);
      return;
    }

    if (matchesKey(data, Key.pageUp)) {
      this.page(-1);
      return;
    }

    const moveDown = matchesKey(data, "j") || matchesKey(data, Key.down);
    const moveUp = matchesKey(data, "k") || matchesKey(data, Key.up);

    if (!moveDown && !moveUp) return;

    const delta = moveDown ? 1 : -1;
    if (this.focusPane === "files") {
      this.moveFile(delta);
      return;
    }
    if (this.focusPane === "diff") {
      this.moveDiff(delta);
      return;
    }
    this.moveMeta(delta);
  }

  render(width: number): string[] {
    const height = Math.max(3, this.tui.terminal.rows);
    const state = [
      width,
      height,
      this.selectedFileIndex,
      this.focusPane,
      this.diffScroll,
      this.metaScroll,
      this.currentHunkIndex,
      this.notice ?? "",
      this.data.mode,
      this.data.files.length,
      this.selectedFile()?.path ?? "",
    ].join(":");

    if (this.cachedWidth === width && this.cachedState === state && this.cachedLines) {
      return this.cachedLines;
    }

    const layout = resolveReviewLayout(width, height);
    let lines: string[];

    if (layout.kind === "wide") {
      lines = this.renderWide(layout, width);
    } else if (layout.kind === "split") {
      lines = this.renderSplit(layout, width);
    } else {
      lines = this.renderStacked(layout, width);
    }

    while (lines.length < height) lines.push(" ".repeat(width));
    if (lines.length > height) lines = lines.slice(0, height);

    this.cachedWidth = width;
    this.cachedState = state;
    this.cachedLines = lines;
    return lines;
  }

  private selectedFile(): ReviewFile | undefined {
    return this.data.files[this.selectedFileIndex];
  }

  private snapshot(): ReviewScreenSnapshot {
    return {
      selectedFileIndex: this.selectedFileIndex,
      selectedFilePath: this.selectedFile()?.path,
      focusPane: this.focusPane,
      diffScroll: this.diffScroll,
      metaScroll: this.metaScroll,
      currentHunkIndex: this.currentHunkIndex,
    };
  }

  private refresh(): void {
    this.invalidate();
    this.tui.requestRender();
  }

  private clearNotice(): void {
    if (this.notice === undefined) return;
    this.notice = undefined;
  }

  private showNotice(message: string): void {
    this.notice = message;
    this.refresh();
  }

  private switchPane(delta: number): void {
    this.clearNotice();
    const order: ReviewPane[] = ["files", "diff", "meta"];
    const index = order.indexOf(this.focusPane);
    const nextIndex = (index + delta + order.length) % order.length;
    this.focusPane = order[nextIndex] ?? "files";
    this.refresh();
  }

  private moveFile(delta: number): void {
    this.clearNotice();
    const nextIndex = clamp(
      this.selectedFileIndex + delta,
      0,
      Math.max(0, this.data.files.length - 1)
    );
    if (nextIndex === this.selectedFileIndex) return;

    this.selectedFileIndex = nextIndex;
    this.diffScroll = 0;
    this.metaScroll = 0;
    this.currentHunkIndex = 0;
    this.refresh();
  }

  private moveDiff(delta: number): void {
    this.clearNotice();
    const prepared = this.prepareDiff(this.lastDiffInnerWidth);
    const maxScroll = Math.max(0, prepared.lines.length - this.lastDiffInnerHeight);
    this.diffScroll = clamp(this.diffScroll + delta, 0, maxScroll);
    this.syncCurrentHunk(prepared);
    this.refresh();
  }

  private moveMeta(delta: number): void {
    this.clearNotice();
    const lines = this.buildMetadataLines(this.lastMetaInnerWidth);
    const maxScroll = Math.max(0, lines.length - this.lastMetaInnerHeight);
    this.metaScroll = clamp(this.metaScroll + delta, 0, maxScroll);
    this.refresh();
  }

  private page(delta: number): void {
    if (this.focusPane === "diff") {
      const amount = Math.max(1, this.lastDiffInnerHeight - 1);
      this.moveDiff(delta * amount);
      return;
    }
    if (this.focusPane === "meta") {
      const amount = Math.max(1, this.lastMetaInnerHeight - 1);
      this.moveMeta(delta * amount);
      return;
    }
    const amount = Math.max(1, Math.floor(this.lastDiffInnerHeight / 2));
    this.moveFile(delta * amount);
  }

  private jumpHunk(delta: number): void {
    this.clearNotice();
    const prepared = this.prepareDiff(this.lastDiffInnerWidth);
    if (prepared.hunkStartLines.length === 0) {
      this.showNotice("selected file has no diff hunks");
      return;
    }

    const nextIndex = clamp(
      this.currentHunkIndex + delta,
      0,
      Math.max(0, prepared.hunkStartLines.length - 1)
    );
    this.currentHunkIndex = nextIndex;
    this.diffScroll = prepared.hunkStartLines[nextIndex] ?? 0;
    this.refresh();
  }

  private getOpenLine(): number {
    const file = this.selectedFile();
    if (!file) return 1;

    const current = file.hunks[this.currentHunkIndex];
    if (current) return Math.max(1, current.newStartLine);

    const first = file.hunks[0];
    return first ? Math.max(1, first.newStartLine) : 1;
  }

  private prepareDiff(innerWidth: number): PreparedDiff {
    const file = this.selectedFile();
    const safeInnerWidth = Math.max(6, innerWidth);
    const cacheKey = `${file?.path ?? "none"}:${safeInnerWidth}`;
    if (this.cachedDiffKey === cacheKey && this.cachedDiff) return this.cachedDiff;

    if (!file) {
      const empty = { lines: ["No file selected."], hunkStartLines: [] };
      this.cachedDiffKey = cacheKey;
      this.cachedDiff = empty;
      return empty;
    }

    const wrappedLines: string[] = [];
    const hunkStartLines: number[] = [];
    const renderedLines = renderDiff(file.diffText, { filePath: file.path }).split("\n");
    const rawLines = file.diffText.split("\n");
    const contentWidth = Math.max(1, safeInnerWidth - 2);

    for (let index = 0; index < renderedLines.length; index += 1) {
      const renderedLine = renderedLines[index] ?? "";
      const rawLine = rawLines[index] ?? "";
      if (rawLine.startsWith("@@")) hunkStartLines.push(wrappedLines.length);

      const wrapped = wrapTextWithAnsi(renderedLine, contentWidth);
      if (wrapped.length === 0) {
        wrappedLines.push("");
      } else {
        wrappedLines.push(...wrapped);
      }
    }

    if (wrappedLines.length === 0) wrappedLines.push("");

    const prepared = { lines: wrappedLines, hunkStartLines };
    this.cachedDiffKey = cacheKey;
    this.cachedDiff = prepared;
    return prepared;
  }

  private syncCurrentHunk(prepared: PreparedDiff): void {
    if (prepared.hunkStartLines.length === 0) {
      this.currentHunkIndex = 0;
      return;
    }

    let nearest = 0;
    for (let index = 0; index < prepared.hunkStartLines.length; index += 1) {
      const line = prepared.hunkStartLines[index];
      if (line > this.diffScroll) break;
      nearest = index;
    }
    this.currentHunkIndex = nearest;
  }

  private renderWide(layout: Extract<ReviewLayout, { kind: "wide" }>, width: number): string[] {
    const files = this.renderFilesPane(layout.filesWidth, layout.height);
    const diff = this.renderDiffPane(layout.diffWidth, layout.height);
    const meta = this.renderMetaPane(layout.metaWidth, layout.height);
    const lines: string[] = [];

    for (let index = 0; index < layout.height; index += 1) {
      const joined = `${files[index] ?? ""} ${diff[index] ?? ""} ${meta[index] ?? ""}`;
      lines.push(truncateToWidth(joined, width, "", true));
    }

    return lines;
  }

  private renderSplit(layout: Extract<ReviewLayout, { kind: "split" }>, width: number): string[] {
    const files = this.renderFilesPane(layout.filesWidth, layout.topHeight);
    const diff = this.renderDiffPane(layout.diffWidth, layout.topHeight);
    const meta = this.renderMetaPane(width, layout.metaHeight);
    const lines: string[] = [];

    for (let index = 0; index < layout.topHeight; index += 1) {
      const joined = `${files[index] ?? ""} ${diff[index] ?? ""}`;
      lines.push(truncateToWidth(joined, width, "", true));
    }

    lines.push(...meta);
    return lines;
  }

  private renderStacked(
    layout: Extract<ReviewLayout, { kind: "stacked" }>,
    width: number
  ): string[] {
    return [
      ...this.renderFilesPane(width, layout.filesHeight),
      ...this.renderDiffPane(width, layout.diffHeight),
      ...this.renderMetaPane(width, layout.metaHeight),
    ];
  }

  private renderFilesPane(width: number, height: number): string[] {
    const innerWidth = Math.max(1, width - 2);
    const innerHeight = Math.max(1, height - 2);
    const fileCount = this.data.files.length;
    const start = centerWindow(fileCount, this.selectedFileIndex, innerHeight);
    const body: string[] = [];

    for (let row = 0; row < innerHeight; row += 1) {
      const file = this.data.files[start + row];
      if (!file) {
        body.push("");
        continue;
      }

      const isSelected = start + row === this.selectedFileIndex;
      const labelWidth = Math.max(4, innerWidth - 4);
      const label = ellipsizePath(file.displayPath, labelWidth);
      let line = `${statusColor(this.theme, file.status)} ${label}`;
      line = truncateToWidth(line, innerWidth, "", true);
      if (isSelected) line = this.theme.bg("selectedBg", line);
      body.push(line);
    }

    const title = `files ${Math.min(this.selectedFileIndex + 1, Math.max(1, fileCount))}/${fileCount || 1}`;
    return this.renderPane(title, body, width, height, this.focusPane === "files");
  }

  private renderDiffPane(width: number, height: number): string[] {
    const file = this.selectedFile();
    const innerWidth = Math.max(1, width - 2);
    const innerHeight = Math.max(1, height - 2);
    this.lastDiffInnerWidth = innerWidth;
    this.lastDiffInnerHeight = innerHeight;

    const prepared = this.prepareDiff(innerWidth);
    const maxScroll = Math.max(0, prepared.lines.length - innerHeight);
    this.diffScroll = clamp(this.diffScroll, 0, maxScroll);
    this.syncCurrentHunk(prepared);

    const currentHunkLine = prepared.hunkStartLines[this.currentHunkIndex] ?? -1;
    const body: string[] = [];
    for (let row = 0; row < innerHeight; row += 1) {
      const absoluteIndex = this.diffScroll + row;
      const line = prepared.lines[absoluteIndex];
      if (line === undefined) {
        body.push("");
        continue;
      }
      const prefix = absoluteIndex === currentHunkLine ? this.theme.fg("accent", "› ") : "  ";
      body.push(truncateToWidth(prefix + line, innerWidth, "", true));
    }

    const rangeStart = prepared.lines.length === 0 ? 0 : this.diffScroll + 1;
    const rangeEnd = Math.min(prepared.lines.length, this.diffScroll + innerHeight);
    const hunkLabel =
      file && file.hunks.length > 0 ? ` ${this.currentHunkIndex + 1}/${file.hunks.length}` : "";
    const title = `diff ${ellipsizePath(path.basename(file?.path ?? "diff"), 16)}${hunkLabel} ${rangeStart}-${rangeEnd}/${prepared.lines.length}`;
    return this.renderPane(title, body, width, height, this.focusPane === "diff");
  }

  private buildMetadataLines(innerWidth: number): string[] {
    const file = this.selectedFile();
    const lines: string[] = [];
    const addWrapped = (text: string = "") => {
      if (!text) {
        lines.push("");
        return;
      }
      const wrapped = wrapTextWithAnsi(text, Math.max(1, innerWidth));
      if (wrapped.length === 0) {
        lines.push("");
      } else {
        lines.push(...wrapped);
      }
    };

    if (this.notice) {
      addWrapped(this.theme.fg("warning", this.notice));
      addWrapped();
    }

    addWrapped(this.theme.fg("accent", this.theme.bold("repo")) + ` ${this.data.repoName}`);
    addWrapped(
      this.theme.fg("muted", "mode") +
        ` ${this.data.mode === "staged" ? "staged index" : "working tree vs HEAD"}`
    );
    addWrapped(this.theme.fg("muted", "focus") + ` ${this.focusPane}`);
    addWrapped();

    if (file) {
      addWrapped(this.theme.fg("accent", this.theme.bold("file")) + ` ${file.displayPath}`);
      addWrapped(this.theme.fg("muted", "status") + ` ${file.statusSummary} (${file.status})`);
      addWrapped(this.theme.fg("muted", "lines") + ` +${file.added} -${file.removed}`);
      addWrapped(this.theme.fg("muted", "hunks") + ` ${file.hunks.length}`);
      addWrapped(
        file.openable
          ? this.theme.fg("muted", "open") +
              ` ${path.basename(file.absolutePath)}:${this.getOpenLine()}`
          : this.theme.fg("warning", "open unavailable (deleted or missing)")
      );
      addWrapped();
    }

    addWrapped(this.theme.fg("accent", this.theme.bold("keys")));
    addWrapped("j / k   move files or scroll pane");
    addWrapped("enter   open selected file in editor");
    addWrapped("n / p   jump next or previous hunk");
    addWrapped("tab     switch focus between panes");
    addWrapped("q / esc close review screen");

    return lines;
  }

  private renderMetaPane(width: number, height: number): string[] {
    const innerWidth = Math.max(1, width - 2);
    const innerHeight = Math.max(1, height - 2);
    this.lastMetaInnerWidth = innerWidth;
    this.lastMetaInnerHeight = innerHeight;

    const bodyLines = this.buildMetadataLines(innerWidth);
    const sliced = sliceWindow(bodyLines, this.metaScroll, innerHeight);
    this.metaScroll = sliced.scroll;

    const start = bodyLines.length === 0 ? 0 : this.metaScroll + 1;
    const end = Math.min(bodyLines.length, this.metaScroll + innerHeight);
    const title = `meta ${start}-${end}/${Math.max(1, bodyLines.length)}`;
    return this.renderPane(title, sliced.lines, width, height, this.focusPane === "meta");
  }

  private renderPane(
    title: string,
    body: string[],
    width: number,
    height: number,
    active: boolean
  ): string[] {
    const safeWidth = Math.max(4, width);
    const safeHeight = Math.max(3, height);
    const innerWidth = safeWidth - 2;
    const innerHeight = safeHeight - 2;
    const border = (text: string) => this.theme.fg(active ? "accent" : "borderMuted", text);
    const titleText = truncateToWidth(
      active
        ? this.theme.fg("accent", this.theme.bold(` ${title} `))
        : this.theme.fg("muted", ` ${title} `),
      innerWidth,
      "",
      false
    );
    const fill = Math.max(0, innerWidth - visibleWidth(titleText));
    const lines: string[] = [border("┌") + titleText + border("─".repeat(fill)) + border("┐")];

    for (let index = 0; index < innerHeight; index += 1) {
      const content = truncateToWidth(body[index] ?? "", innerWidth, "", true);
      lines.push(border("│") + content + border("│"));
    }

    lines.push(border("└") + border("─".repeat(innerWidth)) + border("┘"));
    return lines;
  }
}
