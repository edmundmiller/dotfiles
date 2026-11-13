import {
  getMarkdownTheme,
  getSelectListTheme,
  type ExtensionContext,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import {
  Box,
  HStack,
  Key,
  Markdown,
  MouseRegion,
  ScrollView,
  SelectList,
  Text,
  TruncatedText,
  VStack,
  matchesKey,
  truncateToWidth,
  visibleWidth,
  type Component,
  type KeybindingsManager,
  type TuiMouseEvent,
} from "@earendil-works/pi-tui";
import { stripVTControlCharacters } from "node:util";
import {
  loadThimbleInspection,
  thimbleInspectorSections,
  type ThimbleInspectionLocation,
  type ThimbleInspectionPage,
} from "./thimble-inspection.js";

/** A correction closes the inspector before opening Pi's human-input dialog. */
export interface ThimbleInspectorCorrection {
  location: ThimbleInspectionLocation;
  itemId: string;
  name: string;
  ref: string;
}

interface ThimbleInspectorOptions {
  location: ThimbleInspectionLocation;
  itemId?: string;
  height: () => number;
  refresh: () => void;
  load: (
    location: ThimbleInspectionLocation,
    signal: AbortSignal
  ) => Promise<ThimbleInspectionPage>;
  done: (correction?: ThimbleInspectorCorrection) => void;
}

function safeText(text: string) {
  return stripVTControlCharacters(text).replace(/[\x00-\x08\x0b-\x1f\x7f-\x9f]/g, "");
}

/** Native Pi inspector with keyboard parity in regular and fullscreen modes. */
export class ThimbleInspector implements Component {
  private location: ThimbleInspectionLocation;
  private page: ThimbleInspectionPage = {
    title: "Loading",
    note: "",
    empty: "Loading saved data…",
    items: [],
  };
  private selectedId?: string;
  private list?: SelectList;
  private listHeight = 0;
  private detail: ScrollView;
  private detailRegion?: MouseRegion;
  private focus: "list" | "detail" = "list";
  private loading?: AbortController;
  private closed = false;
  private narrow = false;
  private leftWidth = 0;
  private bodyTop = 0;
  private bodyHeight = 1;
  private tabs: Array<{
    x: number;
    y: number;
    width: number;
    section: ThimbleInspectionLocation["section"];
  }> = [];

  constructor(
    private theme: Pick<Theme, "fg" | "bold" | "inverse">,
    private keys: KeybindingsManager,
    private options: ThimbleInspectorOptions
  ) {
    this.location = options.location;
    this.selectedId = options.itemId;
    this.detail = new ScrollView(new Text("Loading saved data…", 0, 0));
    void this.navigate(this.location, this.selectedId);
  }

  private selected() {
    return this.page.items.find((item) => item.id === this.selectedId);
  }

  private updateDetail() {
    const item = this.selected();
    const text = safeText(item?.detail ?? this.page.empty);
    const content =
      item?.format === "markdown"
        ? new Markdown(text, 0, 0, getMarkdownTheme())
        : new Text(text, 0, 0);
    this.detail = new ScrollView(content, { overscroll: "contain" });
  }

  private async navigate(location: ThimbleInspectionLocation, selectedId?: string) {
    this.loading?.abort();
    const controller = new AbortController();
    this.loading = controller;
    this.location = location;
    this.focus = "list";
    this.list = undefined;
    this.page = {
      title: location.group ?? location.section,
      note: "Loading",
      empty: "Loading saved data…",
      items: [],
    };
    this.updateDetail();
    this.options.refresh();
    try {
      const page = await this.options.load(location, controller.signal);
      if (controller.signal.aborted || this.closed) return;
      this.page = page;
      this.selectedId = page.items.find((item) => item.id === selectedId)?.id ?? page.items[0]?.id;
    } catch (error) {
      if (controller.signal.aborted || this.closed) return;
      this.page = {
        title: location.section,
        note: "Could not load · r retries",
        items: [],
        empty: error instanceof Error ? error.message : String(error),
      };
      this.selectedId = undefined;
    }
    this.loading = undefined;
    this.list = undefined;
    this.updateDetail();
    this.options.refresh();
  }

  private makeList(height: number) {
    if (this.list && this.listHeight === height) return this.list;
    this.listHeight = height;
    this.list = new SelectList(
      this.page.items.map((item) => ({
        value: item.id,
        label: safeText(`[${item.status}] ${item.label}`).replace(/\s+/g, " "),
      })),
      Math.max(1, height - 1),
      getSelectListTheme()
    );
    this.list.setSelectedIndex(
      Math.max(
        0,
        this.page.items.findIndex((item) => item.id === this.selectedId)
      )
    );
    this.list.onSelectionChange = (item) => {
      this.selectedId = item.value;
      this.updateDetail();
      this.options.refresh();
    };
    this.list.onSelect = () => this.openSelected();
    return this.list;
  }

  private openSelected() {
    const item = this.selected();
    if (item?.open) void this.navigate(item.open);
    else this.focus = "detail";
    this.options.refresh();
  }

  private back() {
    if (this.focus === "detail") this.focus = "list";
    else if (this.location.group !== undefined)
      void this.navigate({ section: this.location.section }, this.location.group);
    else this.finish();
    this.options.refresh();
  }

  private finish(correction?: ThimbleInspectorCorrection) {
    this.dispose();
    this.options.done(correction);
  }

  /** Cancel pending engine work; a disposed view cannot receive late results. */
  dispose() {
    this.closed = true;
    this.loading?.abort();
  }

  invalidate() {
    this.list = undefined;
    this.updateDetail();
  }

  render(width: number) {
    this.narrow = width < 88;
    this.tabs = [];
    const tabLines = [""];
    for (const [index, section] of thimbleInspectorSections.entries()) {
      const label = ` ${index + 1} ${section[0].toUpperCase()}${section.slice(1)} `;
      let row = tabLines.length - 1;
      if (visibleWidth(tabLines[row]) + visibleWidth(label) > width && tabLines[row]) {
        tabLines.push("");
        row++;
      }
      const x = visibleWidth(tabLines[row]);
      this.tabs.push({ x, y: row + 1, width: visibleWidth(label), section });
      tabLines[row] +=
        section === this.location.section ? this.theme.inverse(label) : this.theme.fg("dim", label);
    }
    this.bodyTop = 3 + tabLines.length;
    this.bodyHeight = Math.max(1, this.options.height() - this.bodyTop - 1);
    this.leftWidth = this.narrow ? width : Math.min(42, Math.floor(width * 0.36));
    const list = this.makeList(this.bodyHeight);
    const listPane: Component = {
      render: (w) =>
        this.page.items.length
          ? list.render(w)
          : new Text(safeText(this.narrow ? this.page.empty : "No saved items"), 0, 0).render(w),
      invalidate: () => list.invalidate(),
    };
    this.detailRegion = new MouseRegion(
      {
        render: (w) => {
          const lines = this.detail.render(w);
          // Custom screens also run in regular mode, where Pi leaves scrollback
          // to the terminal. Give ScrollView an explicit viewport in both modes.
          this.detail.updateLayout(lines.length, this.bodyHeight, this.options.refresh);
          return lines.slice(this.detail.scrollTop, this.detail.scrollTop + this.bodyHeight);
        },
        invalidate: () => this.detail.invalidate(),
      },
      (event) => {
        if (event.type === "wheel") {
          this.detail.scrollBy(event.wheelDelta ?? 0);
          return { handled: true };
        }
        return undefined;
      }
    );
    const left = new Box(1, 0);
    left.addChild(listPane);
    const right = new Box(1, 0);
    right.addChild(this.detailRegion);
    const body = this.narrow
      ? this.focus === "list"
        ? left
        : right
      : new HStack([
          { component: left, basis: this.leftWidth, shrink: 0 },
          {
            component: new Text(
              Array(this.bodyHeight).fill(this.theme.fg("borderMuted", "│")).join("\n"),
              0,
              0
            ),
            basis: 1,
            shrink: 0,
          },
          { component: right, basis: 0, grow: 1 },
        ]);
    const item = this.selected();
    const status = item?.status ?? (this.loading ? "loading" : "empty");
    const color = status === "verified" ? "success" : status === "wrong" ? "error" : "warning";
    const heading = `${safeText(this.page.title)} · ${this.page.items.length} items · ${this.focus === "list" ? "list" : "details"}`;
    const footer = this.narrow
      ? this.focus === "detail"
        ? " ↑↓ scroll · Tab list · Esc back · q close"
        : ` ↑↓ · Enter open${item?.correction ? " · c correct" : " · 1–5 tabs"} · Esc back`
      : this.focus === "detail"
        ? ` ↑↓ / PgUp/PgDn scroll · line ${this.detail.scrollTop + 1} · Tab list · Esc back · q close`
        : ` ↑↓ select · Enter open · Tab pane · 1–5 sections${item?.correction ? " · c correct" : ""} · Esc back · q close`;
    return new VStack([
      new TruncatedText(this.theme.bold(` THIMBLE  /  ${heading}`), 0, 0),
      new Text(tabLines.join("\n"), 0, 0),
      new TruncatedText(this.theme.fg("dim", ` ${safeText(this.page.note)}`), 0, 0),
      new TruncatedText(
        ` ${this.theme.fg(color, safeText(status))}${this.narrow ? " · Enter/Tab switches panes" : " · list → evidence"}`,
        0,
        0
      ),
      { component: body, basis: this.bodyHeight, shrink: 0 },
      new TruncatedText(this.theme.fg("dim", footer), 0, 0),
    ])
      .render(width)
      .map((line) => truncateToWidth(line, width, "", true));
  }

  handleInput(key: string) {
    const section = thimbleInspectorSections[Number(key) - 1];
    if (/^[1-5]$/.test(key) && section) {
      void this.navigate({ section });
    } else if (key === "q") this.finish();
    else if (this.keys.matches(key, "tui.select.cancel") || matchesKey(key, Key.backspace))
      this.back();
    else if (matchesKey(key, Key.tab)) this.focus = this.focus === "list" ? "detail" : "list";
    else if (key === "r") void this.navigate(this.location, this.selectedId);
    else if (key === "c" && this.selected()?.correction) {
      const item = this.selected()!;
      this.finish({ location: this.location, itemId: item.id, ...item.correction! });
    } else if (this.focus === "list") this.list?.handleInput(key);
    else if (this.keys.matches(key, "tui.select.up")) this.detail.scrollBy(-1);
    else if (this.keys.matches(key, "tui.select.down")) this.detail.scrollBy(1);
    else if (this.keys.matches(key, "tui.select.pageUp")) this.detail.scrollBy(-this.bodyHeight);
    else if (this.keys.matches(key, "tui.select.pageDown")) this.detail.scrollBy(this.bodyHeight);
    else if (matchesKey(key, Key.home)) this.detail.scrollToStart();
    else if (matchesKey(key, Key.end)) this.detail.scrollToEnd();
    this.options.refresh();
  }

  handleMouse(event: TuiMouseEvent) {
    const tab = this.tabs.find(
      (tab) => event.y === tab.y && event.x >= tab.x && event.x < tab.x + tab.width
    );
    if (tab && event.type === "click" && event.button === "left") {
      void this.navigate({ section: tab.section });
      return { handled: true };
    }
    const y = event.y - this.bodyTop;
    if (y < 0 || y >= this.bodyHeight) return undefined;
    const inList = this.narrow ? this.focus === "list" : event.x < this.leftWidth;
    if (inList) {
      this.focus = "list";
      const result = this.list?.handleMouse({
        ...event,
        x: event.x - 1,
        y,
        width: this.leftWidth - 2,
        height: this.bodyHeight,
      });
      this.options.refresh();
      // Keep input ownership on the inspector, not on the nested SelectList.
      return result ? { handled: true } : undefined;
    }
    this.focus = "detail";
    const result = this.detailRegion?.handleMouse({ ...event, y });
    this.options.refresh();
    return result ? { handled: true } : undefined;
  }
}

/** Open a temporary inspector overlay without adding inspected content to model context. */
export async function showThimbleInspector(
  ctx: ExtensionContext,
  location: ThimbleInspectionLocation = { section: "claims" },
  itemId?: string
) {
  if (ctx.mode !== "tui") throw new Error("Thimble inspector requires interactive Pi");
  return ctx.ui.custom<ThimbleInspectorCorrection | undefined>(
    (tui, theme, keys, done) =>
      new ThimbleInspector(theme, keys, {
        location,
        itemId,
        height: () => Math.max(6, tui.terminal.rows - 6),
        refresh: () => tui.requestRender(),
        load: (target, signal) => loadThimbleInspection(ctx, target, signal),
        done,
      }),
    { overlay: true, overlayOptions: { width: "100%", anchor: "center" } }
  );
}
