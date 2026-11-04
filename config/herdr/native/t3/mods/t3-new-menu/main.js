// New, as T3 starts a thread: pick the space (or a new one), then what to run there.
import { View, div, svg, image } from "gpui-kit";
import { h_flex, v_flex, InputState, Input } from "gpui-base";
import {
  theme,
  spaces,
  panes,
  knownAgents,
  run,
  openOverlay,
  closeOverlay,
  props,
  window,
  keys,
  shared,
  home,
  layout,
} from "herdr";

function shortcut(name) {
  const k = keys().find((b) => b.section === "global" && b.action === name);
  if (!k?.keys.trim()) return "";
  const mac = window()?.platform === "macos";
  const names = mac
    ? { ctrl: "⌃", alt: "⌥", shift: "⇧", cmd: "⌘", fn: "fn" }
    : { ctrl: "Ctrl", alt: "Alt", shift: "Shift", cmd: "Super", fn: "Fn" };
  const alias = { secondary: mac ? "cmd" : "ctrl", super: "cmd", win: "cmd" };
  return k.keys
    .trim()
    .split(/\s+/)
    .map((stroke) => {
      const parts = stroke.split("-");
      let key = parts.pop();
      if (key === "") {
        key = "-";
        parts.pop();
      }
      const held = new Set(parts.map((m) => alias[m.toLowerCase()] ?? m.toLowerCase()));
      if (/^[A-Z]$/.test(key)) held.add("shift");
      const label =
        key.length === 1 ? key.toUpperCase() : key[0].toUpperCase() + key.slice(1).toLowerCase();
      return [
        ...Object.keys(names)
          .filter((m) => held.has(m))
          .map((m) => names[m]),
        label,
      ].join(mac ? "" : "+");
    })
    .join(" ");
}

// Space avatars and where a space is now, as t3-spaces draws and says them.
const MARK = {
  ansi6: "#22a99a",
  ansi3: "#e3814f",
  ansi4: "#5b8def",
  ansi5: "#8b7cf6",
  ansi2: "#3fae6a",
  ansi1: "#d9649a",
};
function place(s, ps) {
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return ps.find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}
const NEW = { id: "new", name: "New space" };

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

export default class NewMenu extends View {
  init(_props, cx) {
    this.target = null; // the space picked; null: still picking
    this.at = 0;
    this.filter = "";
    this.agents = {}; // machine → installed agents
    this.input = InputState.new({ placeholder: "Search spaces…" });
    this.input.on("change", (_e, cx) => {
      this.filter = this.input.value();
      this.at = 0;
      cx.notify();
    });
    this.input.on("submit", (_e, cx) => {
      this.choose(this.items()[this.at], cx);
    });
    this.input.focus();
    this.handle = cx.focus_handle();
  }

  items() {
    const ps = panes(),
      cur = spaces().find((s) => s.active),
      q = this.filter.toLowerCase();
    return [cur, NEW, ...spaces().filter((s) => s.id !== cur?.id)]
      .filter(Boolean)
      .filter((s) => `${s.name} ${s === NEW ? "" : place(s, ps)}`.toLowerCase().includes(q));
  }

  // The popup starts fresh each time and the check asks a shell, so it shows the last list (per machine)
  // and swaps in the fresh one when it lands. Only what's installed: the rest is nothing to start.
  installed(machine, cx) {
    const key = `agents:${machine ?? ""}`;
    if (!this.agents[key]) {
      this.agents[key] = { list: JSON.parse(localStorage.getItem(key) ?? "null"), loaded: false };
      cx.spawn(async (cx) => {
        try {
          const list = (await knownAgents({ on: machine })).filter((a) => a.installed);
          this.agents[key] = { list, loaded: true };
          localStorage.setItem(key, JSON.stringify(list));
        } catch {
          this.agents[key].failed = true;
        }
        cx.notify();
      });
    }
    return this.agents[key];
  }

  choose(s, cx) {
    if (!s) return;
    this.target = s;
    this.at = 0;
    this.handle.focus();
    cx.notify();
  }

  start(a) {
    closeOverlay(props().overlay);
    const what = a ? { argv: a.run } : {};
    // Starting anything here means seeing it: the agent view would keep it out of sight.
    if (find(layout(), "view")?.active === "agent")
      run("layout.select", { stack: "view", child: "main" });
    if (this.target === NEW) run("space.new", a ? { ...what, tab: a.name } : what);
    else
      run(
        "tab.new",
        a ? { space: this.target.id, ...what, name: a.name } : { space: this.target.id }
      );
  }

  row(id, i, icon, name, sub, hint, pick) {
    const t = theme(),
      on = this.at === i;
    return h_flex()
      .id(id)
      .h(sub ? 46 : 34)
      .px(10)
      .gap(10)
      .rounded(8)
      .items_center()
      .flex_none()
      .when(on, (el) => el.bg(t.selected))
      .on_hover((over, cx) => {
        if (over && this.at !== i) {
          this.at = i;
          cx.notify();
        }
      })
      .on_click(pick)
      .child(h_flex().size(20).flex_none().items_center().justify_center().child(icon))
      .child(
        v_flex()
          .flex_1()
          .min_w(0)
          .child(div().truncate().text_color(t.foreground).child(name))
          .when(Boolean(sub), (el) =>
            el.child(div().truncate().text_size(11.5).text_color(t.dim).child(sub))
          )
      )
      .child(div().flex_none().text_size(11).text_color(t.dim).child(hint));
  }

  render(cx) {
    const t = theme(),
      ps = panes(),
      h = home();
    const short = (p) => (p && h && p.startsWith(h) ? "~" + p.slice(h.length) : (p ?? ""));
    const colors = shared("space.colors") ?? {};
    const keyDown = (pick, back) => (e, cx) => {
      if (e.key === "escape") return closeOverlay(props().overlay);
      if (e.key === "down") this.at = (this.at + 1) % pick.length;
      else if (e.key === "up") this.at = (this.at + pick.length - 1) % pick.length;
      else if (back && e.key === "backspace") {
        this.target = null;
        this.at = 0;
        this.input.focus();
      } else if (back && e.key === "enter") pick[this.at]?.(cx);
      else if (/^[1-9]$/.test(e.key) && (back || e.modifiers.platform))
        pick[Number(e.key) - (back ? 0 : 1)]?.(cx);
      else return;
      cx.stop_propagation();
      cx.notify();
    };
    const frame = v_flex()
      .id("new-menu")
      .size_full()
      .min_h(0)
      .p(8)
      .gap(4)
      .bg(t.popover)
      .text_size(13);

    if (!this.target) {
      const items = this.items();
      let n = 0;
      const rows = items.map((s, i) => {
        if (s === NEW)
          return this.row(
            "space-new",
            i,
            svg("mods/workspace-chrome/folder-plus.svg").size(16).text_color(t.muted),
            "New space",
            null,
            shortcut("space.new"),
            (_e, cx) => this.choose(NEW, cx)
          );
        const color = colors[s.id] ?? "ansi6",
          fill = color.startsWith("#") ? color : (MARK[color] ?? t[color]);
        const num = ++n;
        return this.row(
          `space-${s.id}`,
          i,
          h_flex()
            .size(18)
            .rounded(5)
            .bg(fill)
            .items_center()
            .justify_center()
            .text_size(11)
            .font_bold()
            .text_color("#ffffff")
            .child([...s.name][0]?.toUpperCase() ?? "?"),
          s.name,
          `${s.machine ?? "Local"} · ${short(place(s, ps))}`,
          num <= 9 ? `⌘${num}` : "",
          (_e, cx) => this.choose(s, cx)
        );
      });
      // ⌘1… go by space number, New space aside.
      const bySpace = items.filter((s) => s !== NEW).map((s) => (cx) => this.choose(s, cx));
      return frame
        .on_key_down((e, cx) => {
          if (e.key === "down" || e.key === "up" || e.key === "escape")
            return keyDown(items, false)(e, cx);
          return keyDown(bySpace, false)(e, cx);
        })
        .child(
          h_flex()
            .h(36)
            .flex_none()
            .px(10)
            .gap(8)
            .items_center()
            .child(svg("mods/workspace-chrome/search.svg").size(14).text_color(t.dim))
            .child(Input.new(this.input).flex_1().h_full().text_size(13).text_color(t.foreground))
        )
        .child(div().px(10).pt(4).pb(2).text_size(11).text_color(t.dim).child("Spaces"))
        .child(v_flex().id("new-spaces").flex_1().min_h(0).overflow_y_scroll().children(rows));
    }

    const space = this.target === NEW ? null : this.target;
    const got = this.installed(space ? space.machine : null, cx);
    const agents = got.list ?? [];
    const picks = [() => this.start(null), ...agents.map((a) => () => this.start(a))];
    return frame
      .track_focus(this.handle)
      .on_key_down(keyDown(picks, true))
      .child(
        h_flex()
          .h(36)
          .flex_none()
          .px(4)
          .gap(6)
          .items_center()
          .child(
            h_flex()
              .id("new-back")
              .size(26)
              .flex_none()
              .items_center()
              .justify_center()
              .rounded(6)
              .text_color(t.dim)
              .hover((s) => s.bg(t.hover))
              .role("button")
              .accessibility_label("Back")
              .on_click((_e, cx) => {
                this.target = null;
                this.at = 0;
                this.input.focus();
                cx.notify();
              })
              .child(svg("mods/workspace-chrome/chevron-left.svg").size(14).text_color(t.dim))
          )
          .child(
            div()
              .truncate()
              .text_color(t.foreground)
              .child(space ? space.name : "New space")
          )
      )
      .child(div().px(10).pt(4).pb(2).text_size(11).text_color(t.dim).child("Start"))
      .child(
        v_flex()
          .id("new-agents")
          .flex_1()
          .min_h(0)
          .overflow_y_scroll()
          .child(
            this.row(
              "terminal",
              0,
              svg("icons/shell.svg").size(14).text_color(t.foreground),
              "Terminal",
              null,
              "",
              () => this.start(null)
            )
          )
          .children(
            agents.map((a, i) =>
              this.row(
                a.key,
                i + 1,
                a.tint ? svg(a.icon).size(14).text_color(t.foreground) : image(a.icon).size(14),
                a.name,
                null,
                i < 9 ? String(i + 1) : "",
                () => this.start(a)
              )
            )
          )
          .when(agents.length === 0, (el) =>
            el.child(
              div()
                .px(10)
                .py(6)
                .text_color(t.dim)
                .child(
                  got.failed
                    ? "Could not load agents"
                    : got.loaded
                      ? "No agents installed"
                      : "Checking installed agents…"
                )
            )
          )
      );
  }
}
