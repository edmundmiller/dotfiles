// The focus sidebar: no spaces, only the agents still asking for attention, as cards, latest news first.
// Below, as in T3: Working (busy agents, folded) and Settled (put away by hand until new work brings them back).
// Settled lives on the agent's own terminal as `settled=<ms>:<turn>`: it ends with the terminal, every mod
// sees it, and a turn ended since says there was new work even while no window watched. Looking doesn't count.

import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex, Popover, InputState, Input } from "gpui-base";
import {
  agents,
  terminals,
  panes,
  spaces,
  focused,
  run,
  hc,
  notify,
  theme,
  shared,
  setShared,
  setAgentOrder,
  props,
  nextCommand,
  settings,
  layout,
} from "herdr";
import { namer } from "./name.js";

const RANK = { blocked: 4, done: 3, working: 2, idle: 1 };
const BUSY = new Set(["working", "blocked"]);
// Space avatar colors, as the Herdr T3 layout's t3-spaces draws them (shared "space.colors").
const MARK = {
  ansi6: "#22a99a",
  ansi3: "#e3814f",
  ansi4: "#5b8def",
  ansi5: "#8b7cf6",
  ansi2: "#3fae6a",
  ansi1: "#d9649a",
};
// The settled tail opens on this many, then grows by MORE.
const FIRST = 10,
  MORE = 25;
// A run that stops stays on the Working shelf this long (ms), as in T3: a quick continuation doesn't move it twice.
const GRACE = 2000;
// The last word when times tie, so the order doesn't follow the order the data came in.
const byAddress = (x, y) => x.address.localeCompare(y.address);

// A sub-agent's own word: error counts as blocked; its done is its parent's news, not its own.
const kidStatus = (k, listed) => {
  const s = listed.get(k.address) ?? k.status;
  return s === "error" ? "blocked" : s === "done" ? "idle" : s;
};

// As T3's sidebar times: no "ago", nothing past days.
function ago(ms, now) {
  const m = Math.floor((now - ms) / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m`;
  if (m < 1440) return `${Math.floor(m / 60)}h`;
  return `${Math.floor(m / 1440)}d`;
}

// How long it's been working, as T3's Working pill: 9s, 4m, 1h 5m.
function took(ms, now) {
  const s = Math.max(0, Math.floor((now - ms) / 1000)),
    m = Math.floor(s / 60);
  return s < 60 ? `${s}s` : m < 60 ? `${m}m` : `${Math.floor(m / 60)}h ${m % 60}m`;
}

// The program's icon from the app's table: a one-color glyph or a picture.
function icon(p, size, color) {
  if (!p?.icon) return null;
  return p.tint
    ? svg(p.icon).size(size).flex_none().text_color(color)
    : image(p.icon).w(size).h(size).flex_none();
}

export default class Focus extends View {
  init(_props, cx) {
    // Each agent's last state, when we saw it set going or come back (ms; 0: before we were watching), the turns
    // it had ended then, and for one that just stopped, when its run started.
    this.changed = JSON.parse(localStorage.getItem("changes") ?? "{}");
    this.open = localStorage.getItem("open") === "true";
    this.workOpen = localStorage.getItem("working-open") === "true";
    this.limit = FIRST;
    // Settled labels written but not back from the core yet: address → value ("" = removed).
    this.pending = {};
    this.hovered = null;
    // The spaces shown, as T3 scopes threads to projects; none: all of them.
    this.scope = JSON.parse(localStorage.getItem("scope") ?? "[]");
    this.scopeOpen = false;
    this.search = InputState.new({ placeholder: "Search spaces…" });
    this.search.on("change", (_e, cx) => cx.notify());
    this.search.on("submit", (_e, cx) => this.pick(this.matches()[0], false, cx));
    // Takes the keyboard while a row is lifted, so Esc can put it back.
    this.keys = cx.focus_handle();
    // "Working 9s" counts up only while such a card shows.
    cx.timer.every(1000, (cx) => {
      if (this.ticking) cx.notify();
    });
    // The cards' times (5m, 2h) move on by the minute, as T3's do.
    cx.timer.every(60000, (cx) => cx.notify());
    // `t3-focus.settle` (cmd-shift-s in keys.json): see settleKey in render.
    cx.spawn(async (cx) => {
      for (;;) {
        if ((await nextCommand()) === "settle") this.settleKey?.(cx);
        cx.notify();
      }
    });
  }

  matches() {
    const q = this.search.value().toLowerCase();
    return [{ id: null, name: "All spaces" }, ...spaces()].filter((s) =>
      s.name.toLowerCase().includes(q)
    );
  }

  // A click shows that space alone; shift-click adds or removes it and keeps the menu open, as in T3.
  pick(s, shift, cx) {
    if (!s) return;
    this.scope = !s.id
      ? []
      : !shift
        ? [s.id]
        : this.scope.includes(s.id)
          ? this.scope.filter((id) => id !== s.id)
          : [...this.scope, s.id];
    localStorage.setItem("scope", JSON.stringify(this.scope));
    // A new scope starts the settled tail over, as T3's does.
    this.limit = FIRST;
    if (!shift) this.scopeOpen = false;
    cx.notify();
  }

  // Takes each agent's state as working, blocked or idle (done counts as idle: looking at it isn't news).
  // A run's place in Working is when it started, as T3's is the person's message: a pause for them, or a stop
  // that goes on within the grace, is the same run. Pinned and settled ones skip the grace, as in T3: their
  // place doesn't hang on it. A turn ended while we weren't watching is news too.
  track(list, all, now, cx) {
    let dirty = false;
    for (const { address, s, turn, excluded } of list) {
      let was = this.changed[address];
      // The grace ran out: back with the person as of then, so it lands on top, and the run is over.
      if (was?.s === "idle" && was.start != null && (excluded || now - was.at >= GRACE)) {
        was = this.changed[address] = {
          s: "idle",
          at: excluded ? now : was.at + GRACE,
          turn: was.turn,
        };
        dirty = true;
      }
      if (was?.s === s && (s !== "idle" || turn <= (was.turn ?? turn))) continue;
      const grace = was?.s === "working" && s === "idle" && !excluded;
      if (grace) cx.timer.after(GRACE, (cx) => cx.notify());
      this.changed[address] = !was
        ? { s, at: 0, turn } // First sight says nothing about when it changed.
        : s === "working"
          ? { s, at: was.start ?? now, turn }
          : s === "blocked"
            ? { s, at: now, turn, start: was.s === "working" ? was.at : was.start }
            : grace
              ? { s, at: now, turn, start: was.at } // Stopped: the grace begins.
              : was.start != null && was.s === "idle"
                ? { ...was, turn } // The turn's end arriving within it.
                : { s, at: now, turn };
      dirty = true;
    }
    if (!dirty) return;
    // Only ended agents lose their record: one missing from the list for a moment comes back to its place.
    const listed = new Set(list.map((a) => a.address));
    const ended = new Set(all.filter((k) => k.state !== "live").map((k) => k.address));
    for (const [k, c] of Object.entries(this.changed))
      if (!listed.has(k) && (ended.has(k) || now - c.at > 30 * 86400000)) delete this.changed[k];
    localStorage.setItem("changes", JSON.stringify(this.changed));
  }

  descendants(all, addr) {
    return all
      .filter((k) => k.parent === addr && k.state === "live")
      .flatMap((k) => [k, ...this.descendants(all, k.address)]);
  }

  // Shown at once; the label comes back from the core a moment later.
  setSettled(addr, value, cx) {
    this.pending[addr] = value;
    cx.spawn(async (cx) => {
      const r = await hc(["label", addr, `settled=${value}`]).catch((e) => ({
        code: 1,
        stderr: String(e),
      }));
      if (r.code === 0) return;
      delete this.pending[addr];
      notify({ title: "Couldn't update the agent", body: r.stderr.trim(), level: "error" });
      cx.notify();
    });
  }

  // Ends a drag or sweep, and hands the keyboard back to the pane that had it, unless the drop moved on to
  // another agent. Not FocusHandle.release(): that frees the handle, and the next drag would throw.
  // `this.back` is set only once something lifted.
  endDrag(restore = true) {
    const back = restore ? this.back : null;
    this.drag = this.sweep = this.back = null;
    if (back?.pane) run("pane.focus", { pane: back.pane });
    else if (back?.terminal) run("pane.focus", { terminal: back.terminal });
    return null;
  }

  render(cx) {
    const t = theme(),
      now = Date.now();
    const every = agents(),
      all = terminals(),
      ps = panes(),
      sp = spaces();
    // A space that's gone reads as all; its id stays stored, so the scope returns with it.
    const scope = this.scope.filter((id) => sp.some((s) => s.id === id));
    const list = scope.length ? every.filter((a) => scope.includes(a.space)) : every;
    const listed = new Map(every.map((a) => [a.address, a.status]));
    const term = new Map(all.map((k) => [k.address, k]));
    for (const [k, v] of Object.entries(this.pending))
      if (!term.has(k) || (term.get(k).labels?.settled ?? "") === v) delete this.pending[k];
    const settledAt = (a) => {
      const v = this.pending[a.address] ?? term.get(a.address)?.labels?.settled;
      return v ? v.split(":").map(Number) : null;
    };
    const kids = new Map(
      every.map((a) => [
        a.address,
        this.descendants(all, a.address).map((k) => kidStatus(k, listed)),
      ])
    );
    // It, or anything under it, is working or needs the person.
    const busy = (a) => BUSY.has(a.status) || kids.get(a.address).some((s) => BUSY.has(s));
    // New work brings a settled agent back: busy now, or a turn ended since it was settled. Hidden ones too.
    for (const a of every) {
      const s = settledAt(a);
      if (s && (busy(a) || (term.get(a.address)?.turn ?? 0) > s[1]))
        this.setSettled(a.address, "", cx);
    }
    // The most urgent of it and what's under it.
    const state = (a) =>
      [a.status, ...kids.get(a.address)].reduce((m, s) =>
        (RANK[s] ?? 0) > (RANK[m] ?? 0) ? s : m
      );
    // Busy, or waiting on sub-agents it will hear back from; needing the person comes first.
    const running = (a) =>
      state(a) !== "blocked" && (a.status === "working" || kids.get(a.address).includes("working"));
    // Pins are the agents list's (t3-agents), one set for both: pinned agents stay up top in pin order, whatever their state.
    const pins = shared("agents.pins") ?? [];
    this.track(
      every.map((a) => ({
        address: a.address,
        s: state(a) === "blocked" ? "blocked" : running(a) ? "working" : "idle",
        turn: term.get(a.address)?.turn ?? 0,
        excluded: pins.includes(a.address) || Boolean(settledAt(a)),
      })),
      all,
      now,
      cx
    );
    const mark = (a) => this.changed[a.address];
    // Seen changing, then; before that, the core's time of its last change. terminals() only has that as of
    // the app's start (status_ms isn't updated live), so it serves only until we see a change ourselves.
    const since = (a) => mark(a)?.at || term.get(a.address)?.status_ms || 0;
    // Just stopped: it shows its state now but keeps its Working place until the grace is out.
    const lingering = (a) => mark(a)?.s === "idle" && mark(a).start != null;
    // T3's Working shelf.
    const working = (a) => running(a) || lingering(a);
    // Active by when each came back to the person; Working by when its run started.
    const newest = (x, y) => since(y) - since(x) || byAddress(x, y);
    const begun = (a) =>
      lingering(a) ? mark(a).start || term.get(a.address)?.status_ms || 0 : since(a);
    // Working since: seen set going; before that, its own report, or for a parent waiting on sub-agents the
    // longest-working one's.
    const started = (a) =>
      mark(a)?.at ||
      (a.status === "working"
        ? term.get(a.address)?.status_ms
        : Math.min(
            Infinity,
            ...this.descendants(all, a.address)
              .filter((k) => kidStatus(k, listed) === "working")
              .map((k) => k.status_ms)
              .filter(Boolean)
          ));
    const pinned = pins.map((p) => list.find((a) => a.address === p)).filter(Boolean);
    const rest = list.filter((a) => !pins.includes(a.address));
    const out = rest.filter((a) => !settledAt(a) && !working(a)).sort(newest);
    const work = rest
      .filter((a) => !settledAt(a) && working(a))
      .sort((x, y) => begun(y) - begun(x) || byAddress(x, y));
    const put = rest
      .filter(settledAt)
      .sort((x, y) => settledAt(y)[0] - settledAt(x)[0] || byAddress(x, y));
    // Shelves fold by default on this screen; the one in view stays out even folded or past the page, so it's never lost.
    const busyRows = this.workOpen ? work : work.filter((a) => a.focused);
    // agent.next goes as the list reads. Only while this list shows: the agents list (t3-agents) sets its own.
    const find = (n) =>
      n?.id === "sidebar-lists" ? n : (n?.children ?? []).map(find).find(Boolean);
    if (find(layout())?.active !== "lists")
      setAgentOrder([...pinned, ...out, ...work, ...put].map((a) => a.address));

    const title = namer();
    const hover = (a) => (on, cx) => {
      if (on) this.hovered = a.address;
      else if (this.hovered === a.address) this.hovered = null;
      cx.notify();
    };
    // A button's icon and text brighten together: a hover style reaches the text but not the svg, so it's state.
    const glow = (id) => (on, cx) => {
      if (on) this.hot = id;
      else if (this.hot === id) this.hot = null;
      cx.notify();
    };
    const lit = (id, color) => (this.hot === id ? t.foreground : color);
    // A space's avatar, as t3-spaces draws it.
    const avatar = (id, name, size) => {
      const color = (shared("space.colors") ?? {})[id] ?? "ansi6";
      return h_flex()
        .size(size)
        .flex_none()
        .rounded(4)
        .bg(color.startsWith("#") ? color : (MARK[color] ?? t[color]))
        .items_center()
        .justify_center()
        .text_size(size * 0.64)
        .font_bold()
        .text_color("#ffffff")
        .child([...(name ?? "")][0]?.toUpperCase() ?? "?");
    };
    // Brought back, it's news again: the top of the list.
    const unsettle = (a, cx) => {
      this.setSettled(a.address, "", cx);
      this.changed[a.address] = { ...this.changed[a.address], at: Date.now(), start: null };
      localStorage.setItem("changes", JSON.stringify(this.changed));
    };
    // Settling the agent in view moves on to the next card down the list, from the top past the end, as T3 does;
    // one in the background moves nothing.
    const settle = (xs, cx) => {
      for (const a of xs)
        this.setSettled(a.address, `${Date.now()}:${term.get(a.address)?.turn ?? 0}`, cx);
      const cards = [...pinned, ...out, ...busyRows],
        i = cards.findIndex((a) => a.focused);
      if (i < 0 || !xs.includes(cards[i])) return false;
      const next = [...cards.slice(i + 1), ...cards.slice(0, i)].find((a) => !xs.includes(a));
      if (next) run("agent.focus", { terminal: next.address });
      return Boolean(next);
    };
    // The settle key: the agent in view, as its card's Settle (finished, unpinned) or its settled row's undo.
    this.settleKey = (cx) => {
      const a = every.find((a) => a.focused);
      if (!a) return;
      if (settledAt(a)) unsettle(a, cx);
      else if (!busy(a) && !pins.includes(a.address)) settle([a], cx);
    };

    // Dragging, as T3's sidebar does it (Sidebar.drag.ts, Sidebar.pointer.ts). Press a row and move 6px to lift it;
    // it follows the pointer up and down inside the list and says what letting go will do. While it's lifted, the
    // Pinned and Active labels open, and the list opens a gap the size of the destination's row where it will
    // land. Pinned keeps a hand-made order; Active and Settled keep their own, so the gap opens where that puts it.
    let d = this.drag;
    // A row that leaves the list (its agent ended, a filter) can't be dropped. Render can't run commands, so
    // `this.back` stays and the release (or Esc, or leaving) hands the keyboard back.
    if (d && !list.some((a) => a.address === d.from)) d = this.drag = null;
    const dragging = Boolean(d?.moved);
    const lifted = dragging ? list.find((a) => a.address === d.from) : null;
    const sectionOf = (a) =>
      pins.includes(a.address)
        ? "pinned"
        : settledAt(a)
          ? "settled"
          : working(a)
            ? "working"
            : "active";
    const from = lifted ? sectionOf(lifted) : null;
    const others = (xs) => xs.filter((x) => x.address !== d?.from);
    const pinTo = (before) => ({ section: "pinned", before: before ?? null });
    const pinOrder = (before) => {
      const kept = pins.filter((p) => p !== d.from),
        at = before ? kept.indexOf(before) : -1;
      kept.splice(at < 0 ? kept.length : at, 0, d.from);
      return kept;
    };
    // What letting go would do, and the gap that shows it: above a row (its address), after a section's last row
    // (`end-…`), right under an empty section's label (`head-…`), or none (a folded or busy destination).
    const plan = (() => {
      const to = lifted && d.target;
      if (!to || (to.section === from && from !== "pinned")) return null;
      if (to.section === "pinned") {
        const order = pinOrder(to.before);
        if (from === "pinned" && order.join("\n") === pins.join("\n")) return null;
        return {
          section: "pinned",
          order,
          gap: to.before ?? (others(pinned).length ? "end-pinned" : "head-pinned"),
        };
      }
      // Busy work can't be settled (new work brings it straight back); out of Pinned it joins the Working shelf.
      if (busy(lifted)) return to.section === "settled" ? null : { section: "active", gap: null };
      if (to.section === "settled")
        return {
          section: "settled",
          gap: !this.open ? null : (others(put)[0]?.address ?? "head-settled"),
        };
      const rest = others(out),
        at = from === "settled" ? 0 : rest.filter((x) => newest(x, lifted) < 0).length;
      return {
        section: "active",
        gap: !rest.length ? "head-active" : (rest[at]?.address ?? "end-active"),
      };
    })();
    const target = dragging ? (d.target?.section ?? null) : null;
    // A section lights up as the target, as T3's labels and shelf header do.
    const hot = (s) => target === s && (Boolean(plan) || s === from);
    const verb = !plan
      ? null
      : plan.section === "pinned"
        ? from === "pinned"
          ? null
          : "pin"
        : plan.section === "settled"
          ? "settle"
          : from === "pinned"
            ? "unpin"
            : from === "settled"
              ? "unsettle"
              : null;
    const BADGE = {
      pin: ["mods/workspace-chrome/pin.svg", "Pin"],
      unpin: ["mods/workspace-chrome/pin-off.svg", "Unpin"],
      settle: ["mods/workspace-chrome/circle-check.svg", "Settle"],
      unsettle: ["mods/t3-focus/undo.svg", "Un-settle"],
    };
    const badge = (v) =>
      h_flex()
        .id(`badge-${v}`)
        .h(20)
        .px(6)
        .gap(4)
        .flex_none()
        .items_center()
        .rounded(4)
        .border(1)
        .border_color(t.accent + "66")
        .bg(t.accent + "1a")
        .text_size(11)
        .font_medium()
        .text_color(t.accent)
        .child(svg(BADGE[v][0]).size(12).flex_none().text_color(t.accent))
        .child(BADGE[v][1]);

    // Settled shows one page; while a drag moves a row out of it the next row fills in, and one settled into
    // it pushes the page's last row out of sight.
    const fromPage = from === "settled" && put.indexOf(lifted) < this.limit;
    const size =
      this.limit +
      (fromPage && plan ? 1 : 0) -
      (plan?.section === "settled" && from !== "settled" ? 1 : 0);
    const page = this.open ? put.slice(0, size) : [];
    const rows = [...page, ...put.filter((a) => a.focused && !page.includes(a))];

    const aim = (to, cx) => {
      if (!this.drag?.moved || JSON.stringify(this.drag.target ?? null) === JSON.stringify(to))
        return;
      this.drag.target = to;
      cx.notify();
    };
    // Over a pin, the upper half drops above it and the lower half below.
    const pinNear = (a, upper) => {
      const xs = pinned.map((x) => x.address),
        i = xs.indexOf(a.address);
      return pinTo(xs.slice(upper && a.address !== d?.from ? i : i + 1).find((x) => x !== d?.from));
    };
    // The gap: a card and the list's 2px in Pinned and Active, a 30px slim row in Settled (stacked without gaps).
    const MOTION = { duration: 150, easing: "ease-out" };
    const cardH = lifted && from !== "settled" ? d.height : (this.cardH ?? 82);
    const gap = (key) =>
      div()
        .id(`gap-${key}`)
        .flex_none()
        .h(plan?.gap !== key ? 0 : plan.section === "settled" ? 30 : cardH + 2)
        .when(dragging, (el) => el.transition("height", MOTION));
    // Each droppable row sits in a lane: the gap that opens above it, the row (folding away once the lifted one is
    // headed elsewhere, holding its place until then) with the list's spacing, and after the last, the end gap.
    const lane = (section, xs, draw, spacing) =>
      xs.map((a, i) =>
        v_flex()
          .id(`lane-${a.address}`)
          .flex_none()
          .child(gap(a.address))
          .child(
            v_flex()
              .id(`hold-${a.address}`)
              .flex_none()
              .when(dragging && d.from === a.address, (el) =>
                el
                  .overflow_hidden()
                  .opacity(0)
                  .h(plan ? 0 : d.height + spacing)
                  .transition("height", MOTION)
              )
              .child(draw(a))
              .when(spacing > 0, (el) => el.child(div().h(spacing).flex_none()))
          )
          .when(i === xs.length - 1, (el) => el.child(gap(`end-${section}`)))
      );
    // T3's boundaries: Pinned and Active labels, shown only while dragging; the list opens room for them.
    const boundary = (id, text, section, to) =>
      h_flex()
        .id(id)
        .flex_none()
        .overflow_hidden()
        .h(dragging ? 24 : 0)
        .transition("height", MOTION)
        .px(10)
        .gap(8)
        .items_center()
        .text_size(12)
        .font_medium()
        .on_mouse_move((_e, cx) => aim(to, cx))
        .when(dragging, (el) =>
          el
            .child(
              div()
                .text_color(hot(section) ? t.accent : t.muted)
                .child(text)
            )
            .child(
              div()
                .flex_1()
                .h(1)
                .bg(hot(section) ? t.accent + "80" : t.border)
            )
        );
    // An empty section still takes a drop: T3's dashed placeholder, accent while it's the target.
    const placeholder = (section, text) =>
      div()
        .id(`${section}-placeholder`)
        .h(36)
        .mb(2)
        .flex_none()
        .flex()
        .items_center()
        .justify_center()
        .rounded(6)
        .border(1)
        .border_dashed()
        .text_size(12)
        .border_color(hot(section) ? t.accent + "66" : t.border)
        .text_color(hot(section) ? t.accent : t.muted)
        .when(hot(section), (el) => el.bg(t.accent + "0d"))
        .on_mouse_move((_e, cx) => aim({ section }, cx))
        .child(text);
    // Picked up anywhere on a row that can move (not Working, not one whose Settle is still on its way).
    const row = (el, a) =>
      el
        .on_mouse_down("left", (e) => {
          if (sectionOf(a) === "working" || this.pending[a.address] !== undefined) return;
          this.drag = {
            from: a.address,
            at: e.position,
            grab: e.local_position?.y ?? 0,
            height: e.bounds?.height ?? 0,
            moved: false,
            target: null,
          };
        })
        .on_mouse_move((e, cx) => {
          if (this.sweep?.moved) return sweepTo(a, cx);
          const s = sectionOf(a);
          aim(
            s === "pinned"
              ? pinNear(a, (e.local_position?.y ?? 0) < (e.bounds?.height ?? 0) / 2)
              : s === "working"
                ? null
                : { section: s },
            cx
          );
        });
    // A drag's or sweep's release doesn't also click the row or button it ends on.
    const justDropped = () =>
      this.drag?.moved || this.sweep?.moved || Date.now() - (this.dropped ?? 0) < 250;
    const open = (a) => () => {
      if (justDropped()) return;
      run("agent.focus", { terminal: a.address });
    };
    // Says whether it moved on to another agent.
    const drop = (cx) => {
      if (!plan) return false;
      const a = lifted;
      if (plan.section === "pinned") setShared("agents.pins", plan.order);
      else if (pins.includes(a.address))
        setShared(
          "agents.pins",
          pins.filter((p) => p !== a.address)
        );
      if (plan.section === "settled") return settle([a], cx);
      if (settledAt(a)) unsettle(a, cx);
      return false;
    };

    // Sweep, T3's other drag: press a card's Settle (or a settled row's undo) and move across rows to take the
    // whole run along; letting go settles (or brings back) every row it marked.
    const sweepFrom = (action, a) => (e, cx) => {
      cx.stop_propagation();
      this.sweep = { action, origin: a.address, at: e.position, moved: false, keys: [a.address] };
    };
    const sweepList = () => (this.sweep.action === "settle" ? out.filter((x) => !busy(x)) : rows);
    const sweepTo = (a, cx) => {
      const xs = sweepList().map((x) => x.address),
        i = xs.indexOf(this.sweep.origin),
        j = xs.indexOf(a.address);
      if (i < 0 || j < 0) return;
      const keys = xs.slice(Math.min(i, j), Math.max(i, j) + 1);
      if (keys.join("\n") === this.sweep.keys.join("\n")) return;
      this.sweep.keys = keys;
      cx.notify();
    };
    const swept = (a) => Boolean(this.sweep?.moved && this.sweep.keys.includes(a.address));
    const finish = (cx) => {
      if (!this.drag && !this.sweep && !this.back) return;
      const moved = (dragging && drop(cx)) || (Boolean(this.sweep?.moved) && applySweep(cx));
      if (dragging || this.sweep?.moved) this.dropped = Date.now();
      this.endDrag(!moved);
    };
    const applySweep = (cx) => {
      const xs = sweepList().filter((x) => this.sweep.keys.includes(x.address));
      if (this.sweep.action === "settle") return settle(xs, cx);
      for (const a of xs) unsettle(a, cx);
      return false;
    };

    // `ghost`: the copy that follows the pointer, drawn without handlers or ids the list already uses.
    const card = (a, ghost) => {
      const st = state(a),
        on = a.focused;
      const machine = a.address.includes("/") ? a.address.split("/")[0] : null;
      const branch = ps.find((p) => p.pane === a.pane)?.branch;
      const going = kids.get(a.address).filter((s) => s === "working").length;
      const meta = [branch, going ? `${going} sub-agent${going > 1 ? "s" : ""} working` : null]
        .filter(Boolean)
        .join(" · ");
      const pic = icon(a.program, 16, t.muted);
      // Hovered, the corner offers Settle, but only for what's finished: a working or stuck tree stays in sight.
      const offer =
        !dragging &&
        !this.sweep?.moved &&
        this.hovered === a.address &&
        !busy(a) &&
        !pins.includes(a.address);
      const id = `settle-${a.address}`;
      // As in T3, the corner says the state when there's one worth saying (Working, Needs you, Done: finished
      // and not yet seen), else how long ago it last changed. Sized as T3's: 16px mark, 4px gaps, and the
      // time a separate monospace child, so spacing and width don't hang on the interface font.
      const pill = (color, mark, label, time) =>
        h_flex()
          .id(`state-${a.address}`)
          .h(20)
          .gap(4)
          .flex_none()
          .items_center()
          .font_medium()
          .text_color(color)
          .child(mark)
          .child(div().child(label))
          .when(Boolean(time), (el) =>
            el.child(
              div()
                .font_family(settings().font_family ?? "JetBrains Mono")
                .child(time)
            )
          );
      // Lifted, or marked by a sweep, the corner says what letting go will do instead.
      const corner = ghost
        ? verb
          ? badge(verb)
          : div()
        : swept(a)
          ? badge("settle")
          : offer
            ? h_flex()
                .id(id)
                .h(20)
                .px(6)
                .gap(4)
                .flex_none()
                .items_center()
                .rounded(6)
                .text_size(12)
                .text_color(lit(id, t.muted))
                .on_hover(glow(id))
                .role("button")
                .accessibility_label("Settle")
                .on_mouse_down("left", sweepFrom("settle", a))
                .on_click((_e, cx) => {
                  cx.stop_propagation();
                  if (justDropped()) return;
                  // A click is no sweep. Its release stops here, so the sidebar's mouse-up won't end the one the press began.
                  this.sweep = null;
                  // The card moves away without a pointer-leave event.
                  this.hovered = null;
                  settle([a], cx);
                  cx.notify();
                })
                .child(
                  svg("mods/workspace-chrome/check.svg")
                    .size(12)
                    .flex_none()
                    .text_color(lit(id, t.muted))
                )
                .child("Settle")
            : running(a)
              ? pill(
                  t.working,
                  svg("mods/workspace-chrome/spinner.svg")
                    .size(16)
                    .flex_none()
                    .text_color(t.working)
                    .spin(900),
                  "Working",
                  started(a) > 0 && started(a) < Infinity ? took(started(a), now) : null
                )
              : st === "blocked"
                ? pill(
                    t.blocked,
                    div()
                      .size(14)
                      .flex_none()
                      .rounded(4)
                      .bg(t.blocked + "26")
                      .text_size(11)
                      .font_bold()
                      .flex()
                      .items_center()
                      .justify_center()
                      .child("!"),
                    "Needs you"
                  )
                : st === "done"
                  ? pill(
                      t.ansi2,
                      svg("mods/workspace-chrome/circle-check.svg")
                        .size(16)
                        .flex_none()
                        .text_color(t.ansi2),
                      "Done"
                    )
                  : div()
                      .id(`state-${a.address}`)
                      .flex_none()
                      .child(since(a) > 0 ? ago(since(a), now) : "");
      const base = v_flex()
        .id(`${ghost ? "ghost-" : ""}card-${a.address}`)
        .px(10)
        .py(8)
        .gap(2)
        .flex_none()
        .rounded(10);
      return (
        ghost
          ? base
          : row(base, a)
              .role("button")
              .accessibility_label(title(a))
              .on_hover(hover(a))
              // agent.focus, not pane.focus: in tabs it focuses the pane, and it picks what the agent view shows.
              .on_click(open(a))
              .on_size_change((size) => {
                this.cardH = size.height;
              })
      )
        .when(on, (el) => el.bg(t.selected))
        .when(!on && !ghost && !dragging && !this.sweep?.moved, (el) =>
          el.hover((s) => s.bg(t.hover))
        )
        .child(
          h_flex()
            .h(20)
            .gap(6)
            .items_center()
            .text_size(12)
            .text_color(t.dim)
            .child(avatar(a.space, a.space_name, 14))
            // Lifted, a pin keeps its glyph only while it stays among the pins.
            .when(
              pins.includes(a.address) && (!ghost || plan?.section === "pinned" || !plan),
              (el) =>
                el.child(
                  svg("mods/workspace-chrome/pin.svg").size(12).flex_none().text_color(t.dim)
                )
            )
            .child(
              div()
                .flex_1()
                .min_w(0)
                .truncate()
                .child(machine ? `${a.space_name} · ${machine}` : (a.space_name ?? ""))
            )
            .child(corner)
        )
        .child(
          h_flex()
            .gap(8)
            .items_center()
            // Only the one in view is bright, as in T3.
            .child(
              div()
                .flex_1()
                .min_w(0)
                .truncate()
                .text_size(14)
                .text_color(on ? t.foreground : t.muted)
                .child(title(a))
            )
            .when(Boolean(pic), (el) => el.child(pic))
        )
        .when(Boolean(meta), (el) =>
          el.child(div().min_w(0).truncate().text_size(12).text_color(t.dim).child(meta))
        );
    };

    // A settled row: one dim line; viewing it leaves it settled. Hovered it brightens and its time
    // becomes a bare undo arrow, as in T3.
    const slim = (a, ghost) => {
      const on = a.focused,
        over = !dragging && !this.sweep?.moved && this.hovered === a.address,
        bright = on || over || ghost || swept(a);
      const pic = icon(a.program, 14, t.dim);
      const undo = h_flex()
        .id(`unsettle-${a.address}`)
        .size(20)
        .flex_none()
        .items_center()
        .justify_center()
        .rounded(4)
        .on_hover(glow(`unsettle-${a.address}`))
        .role("button")
        .accessibility_label("Unsettle")
        .on_mouse_down("left", sweepFrom("unsettle", a))
        .on_click((_e, cx) => {
          cx.stop_propagation();
          if (justDropped()) return;
          this.sweep = null;
          this.hovered = null;
          unsettle(a, cx);
          cx.notify();
        })
        .child(
          svg("mods/t3-focus/undo.svg")
            .size(14)
            .flex_none()
            .text_color(lit(`unsettle-${a.address}`, t.muted))
        );
      const base = h_flex()
        .id(`${ghost ? "ghost-" : ""}slim-${a.address}`)
        .h(30)
        .px(10)
        .gap(8)
        .flex_none()
        .items_center()
        .rounded(8);
      return (
        ghost
          ? base
          : row(base, a)
              .role("button")
              .accessibility_label(title(a))
              .on_hover(hover(a))
              .on_click(open(a))
      )
        .when(on, (el) => el.bg(t.selected))
        .when(!on && !ghost && !dragging && !this.sweep?.moved, (el) =>
          el.hover((s) => s.bg(t.hover))
        )
        .child(
          h_flex()
            .size(16)
            .flex_none()
            .items_center()
            .justify_center()
            .opacity(bright ? 1 : 0.5)
            .when(Boolean(pic), (el) => el.child(pic))
        )
        .child(
          div()
            .flex_1()
            .min_w(0)
            .truncate()
            .text_color(bright ? t.foreground : t.muted)
            .child(title(a))
        )
        .child(
          ghost
            ? verb
              ? badge(verb)
              : div()
            : swept(a)
              ? badge("unsettle")
              : over
                ? undo
                : div()
                    .flex_none()
                    .text_size(12)
                    .text_color(t.dim)
                    .child(ago(settledAt(a)[0], now))
        );
    };

    // A shelf's header, folding it: label, then count and chevron at the far edge.
    const shelf = (id, label, count, open, toggle, extra) =>
      h_flex()
        .id(id)
        .h(30)
        .px(10)
        .gap(6)
        .flex_none()
        .items_center()
        .text_size(12)
        .font_medium()
        .text_color(t.dim)
        .role("button")
        .accessibility_label(`${open ? "Hide" : "Show"} ${label.toLowerCase()} agents`)
        .on_click((_e, cx) => {
          toggle();
          cx.notify();
        })
        .child(div().flex_1().child(label))
        .when(Boolean(extra), (el) => el.child(extra))
        .child(div().child(String(count)))
        .child(
          svg(`mods/workspace-chrome/chevron-${open ? "down" : "right"}.svg`)
            .size(12)
            .flex_none()
        );

    this.ticking = busyRows.length > 0 || pinned.some(working);
    // The first shelf takes the free space above it, so both sit at the bottom.
    const shelves = v_flex()
      .id("shelves")
      .pt(12)
      .flex_none()
      .when(work.length > 0, (el) =>
        el
          .child(
            shelf("working-header", "Working", work.length, this.workOpen, () => {
              this.workOpen = !this.workOpen;
              localStorage.setItem("working-open", String(this.workOpen));
            }).on_mouse_move((_e, cx) => aim(null, cx))
          )
          .child(
            v_flex()
              .gap(2)
              .children(busyRows.map((a) => card(a)))
          )
      );
    // Clear closes settled agents' panes; Herdr then closes emptied tabs. The one in view stays.
    const spaceNow = sp.find((s) => s.active),
      tabNow = spaceNow?.tabs.find((c) => c.active)?.id;
    const doomed = put.filter((a) => a.pane && !a.focused && a.tab !== tabNow);
    // With nothing to clear the button goes, and a gone element hears no pointer-leave: drop its ask and hover.
    if (doomed.length === 0) {
      this.clearing = false;
      if (this.hot === "settled-clear") this.hot = null;
    }
    // The ask ends a moment after the pointer leaves the button, or after 3s if the pointer never came (keyboard).
    const unask = (ms, cx) => {
      this.unask?.cancel();
      this.unask =
        ms > 0
          ? cx.timer.after(ms, (cx) => {
              this.clearing = false;
              cx.notify();
            })
          : null;
    };
    const clear = (cx) => {
      if (!this.clearing) {
        this.clearing = true;
        unask(this.hot === "settled-clear" ? 0 : 3000, cx);
        return;
      }
      this.clearing = false;
      unask(0, cx);
      const gone = new Set(doomed.map((a) => a.pane));
      for (const id of new Set(doomed.map((a) => a.space))) {
        const s = sp.find((s) => s.id === id),
          tabs = s?.tabs.map((c) => c.id) ?? [];
        const mine = ps.filter((p) => tabs.includes(p.tab));
        // The space stays: pane.close refuses its last pane, so a space left empty gets a fresh shell tab first,
        // where its terminals are now: an unnamed space is named after that, and s.folder is only where it began.
        if (mine.every((p) => gone.has(p.pane)))
          run("tab.new", { space: id, folder: mine.find((p) => p.cwd)?.cwd || s.folder });
        for (const a of doomed.filter((a) => a.space === id)) run("pane.close", { pane: a.pane });
      }
      // tab.new shows the new tab; go back to where the person was.
      if (tabNow) {
        run("space.select", { id: spaceNow.id });
        run("tab.select", { id: tabNow });
      }
    };
    const clearButton =
      doomed.length > 0 &&
      h_flex()
        .id("settled-clear")
        .h(20)
        .px(6)
        .flex_none()
        .items_center()
        .rounded(4)
        .text_color(this.clearing ? t.blocked : lit("settled-clear", t.dim))
        .on_hover((on, cx) => {
          if (this.clearing) unask(on ? 0 : 400, cx);
          glow("settled-clear")(on, cx);
        })
        .role("button")
        .accessibility_label(
          this.clearing ? `Close ${doomed.length} settled agents` : "Clear settled agents"
        )
        .on_click((e, cx) => {
          cx.stop_propagation();
          // A double-click only asks: the second click of it never answers.
          if (this.clearing && e.click_count > 1) return;
          clear(cx);
          cx.notify();
        })
        .child(this.clearing ? `Clear ${doomed.length}?` : "Clear");
    const tail = v_flex()
      .id("settled")
      .flex_none()
      .child(
        shelf(
          "settled-header",
          "Settled",
          put.length,
          this.open,
          () => {
            this.open = !this.open;
            this.limit = FIRST;
            localStorage.setItem("open", String(this.open));
          },
          clearButton
        )
          .on_mouse_move((_e, cx) => aim({ section: "settled" }, cx))
          // As T3's shelf header: brighter while anything is lifted, accent as the target.
          .when(dragging, (el) => el.text_color(hot("settled") ? t.accent : t.foreground))
      )
      .when(dragging && others(rows).length === 0 && !(rows.length > 0 && !plan), (el) =>
        el.child(
          plan?.gap === "head-settled" ? gap("head-settled") : placeholder("settled", "Settled")
        )
      )
      .children(lane("settled", rows, (a) => slim(a), 0))
      .when(this.open && put.length > this.limit, (el) =>
        el.child(
          h_flex()
            .id("settled-more")
            .h(30)
            .px(10)
            .gap(8)
            .flex_none()
            .items_center()
            .rounded(8)
            .text_color(t.dim)
            .hover((s) => s.bg(t.hover).text_color(t.foreground))
            .role("button")
            .accessibility_label("Show more settled agents")
            .on_click((_e, cx) => {
              this.limit += MORE;
              cx.notify();
            })
            .child(svg("mods/workspace-chrome/chevron-down.svg").size(12).flex_none())
            .child(`Show ${Math.min(MORE, put.length - this.limit)} more`)
        )
      );

    // T3's top row: search on the left, then the space filter, new space and new agent.
    const tool = (id, label, icon, fn) =>
      div()
        .id(id)
        .size(26)
        .flex_none()
        .flex()
        .items_center()
        .justify_center()
        .rounded(6)
        .hover((s) => s.bg(t.hover))
        .on_hover(glow(id))
        .role("button")
        .accessibility_label(label)
        .on_click(fn)
        .child(svg(`mods/workspace-chrome/${icon}.svg`).size(14).text_color(lit(id, t.dim)));
    // The filter shows what it filters to: one avatar, two overlapping, or the plain filter icon.
    const scoped = sp.filter((s) => scope.includes(s.id));
    const choice = (s) => {
      const on = s.id ? scope.includes(s.id) : scope.length === 0;
      // Selection is a check badge on the icon, as in T3.
      return h_flex()
        .id(`scope-${s.id ?? "all"}`)
        .h(32)
        .px(8)
        .gap(10)
        .flex_none()
        .items_center()
        .rounded(6)
        .hover((st) => st.bg(t.hover))
        .role("button")
        .accessibility_label(s.name)
        .on_click((e, cx) => this.pick(s, e.modifiers.shift, cx))
        .child(
          div()
            .relative()
            .flex_none()
            .child(
              s.id
                ? avatar(s.id, s.name, 16)
                : svg("mods/workspace-chrome/folder.svg").size(16).text_color(t.muted)
            )
            .when(on, (el) =>
              el.child(
                h_flex()
                  .absolute()
                  .right(-4)
                  .bottom(-4)
                  .size(12)
                  .rounded_full()
                  .bg(t.accent)
                  .border(2)
                  .border_color(t.popover)
                  .items_center()
                  .justify_center()
                  .child(svg("mods/workspace-chrome/check.svg").size(7).text_color("#ffffff"))
              )
            )
        )
        .child(div().flex_1().min_w(0).truncate().text_color(t.foreground).child(s.name));
    };
    const filter = Popover.new("focus-scope-menu")
      .anchor("top_right")
      .open(this.scopeOpen)
      .on_open_change((open, cx) => {
        this.scopeOpen = open;
        if (open) {
          this.search.set_value("");
          this.search.focus();
        }
        cx.notify();
      })
      .trigger(
        h_flex()
          .id("focus-scope")
          .size(26)
          .flex_none()
          .items_center()
          .justify_center()
          .rounded(6)
          .hover((s) => s.bg(t.hover))
          .on_hover(glow("focus-scope"))
          .role("button")
          .accessibility_label(
            scoped.length
              ? `Filter by space: ${scoped.map((s) => s.name).join(", ")}`
              : "Filter by space"
          )
          .child(
            scoped.length > 1
              ? h_flex().children(
                  scoped
                    .slice(0, 2)
                    .map((s, i) => avatar(s.id, s.name, 14).when(i > 0, (el) => el.ml(-6)))
                )
              : scoped.length
                ? avatar(scoped[0].id, scoped[0].name, 16)
                : svg("mods/t3-focus/list-filter.svg")
                    .size(14)
                    .text_color(lit("focus-scope", t.dim))
          )
      )
      .content(
        v_flex()
          .id("focus-scope-panel")
          .w(260)
          .max_h(360)
          .mt(4)
          .p(6)
          .gap(2)
          .rounded(10)
          .bg(t.popover)
          .border_1()
          .border_color(t.border)
          .text_size(13)
          .child(
            h_flex()
              .h(32)
              .px(8)
              .gap(8)
              .flex_none()
              .items_center()
              .border_b_1()
              .border_color(t.border)
              .child(svg("mods/workspace-chrome/search.svg").size(14).flex_none().text_color(t.dim))
              .child(
                Input.new(this.search).flex_1().h_full().text_size(13).text_color(t.foreground)
              )
          )
          .child(
            v_flex()
              .id("focus-scope-list")
              .min_h(0)
              .pt(4)
              .gap(2)
              .overflow_y_scroll()
              .children(this.matches().map(choice))
              .when(this.matches().length === 0, (el) =>
                el.child(div().px(8).py(6).text_color(t.dim).child("No matching spaces."))
              )
          )
      );
    // Right edge as the brand bar's above (pr 10), so the two rows of icons line up.
    const top = h_flex()
      .id("focus-top")
      .h(32)
      .pl(8)
      .pr(10)
      .gap(2)
      .flex_none()
      .items_center()
      .child(
        h_flex()
          .id("focus-search")
          .flex_1()
          .h(26)
          .px(10)
          .gap(8)
          .items_center()
          .rounded(6)
          .text_color(lit("focus-search", t.dim))
          .hover((s) => s.bg(t.hover))
          .on_hover(glow("focus-search"))
          .role("button")
          .accessibility_label("Search")
          .on_click(() => run("mod.open", { name: "picker" }))
          .child(
            svg("mods/workspace-chrome/search.svg")
              .size(14)
              .flex_none()
              .text_color(lit("focus-search", t.dim))
          )
          .child(div().child("Search"))
      )
      .child(filter)
      .child(tool("focus-new-space", "New space", "folder-plus", () => run("space.new")))
      // The layout passes its own menu; docked alone, the shipped one.
      .child(
        tool("focus-new-agent", "New agent", "square-pen", () =>
          run("mod.open", { name: props()?.newMenu ?? "new-menu" })
        )
      );

    return (
      v_flex()
        .id("t3-focus-root")
        .relative()
        .size_full()
        .min_h(0)
        .bg(t.chrome)
        .text_size(13)
        .on_size_change((size) => {
          this.height = size.height;
          this.width = size.width;
        })
        // Esc puts a lifted row back (the sidebar holds the keyboard only while something is lifted).
        .track_focus(this.keys)
        .on_key_down((e, cx) => {
          if (e.keystroke !== "escape" || !(this.drag || this.sweep || this.back)) return;
          this.endDrag();
          cx.notify();
        })
        .on_mouse_move((e, cx) => {
          const g = this.drag ?? this.sweep;
          if (!g || (!g.moved && Math.hypot(e.position.x - g.at.x, e.position.y - g.at.y) <= 6))
            return;
          if (!g.moved) {
            this.back = focused();
            this.keys.focus();
          }
          g.moved = true;
          g.last = e.local_position ?? g.last;
          if (this.drag) this.drag.y = e.local_position?.y ?? this.drag.y;
          cx.notify();
        })
        // Released anywhere in the sidebar, it lands where the gap shows.
        .on_mouse_up("left", (_e, cx) => {
          finish(cx);
          cx.notify();
        })
        // Herdr reports no release outside the sidebar, so leaving decides. Off the top or bottom edge (the Pinned
        // label or the Settled shelf sit there) it lands where the badge says, as T3 keeps the last target past the
        // list's ends; off a side it goes back.
        .on_hover((on, cx) => {
          if (on || !(this.drag || this.sweep || this.back)) return;
          const p = (this.drag ?? this.sweep)?.last,
            w = this.width ?? Infinity,
            h = this.height ?? Infinity;
          const side = !p || Math.min(p.x, w - p.x) < Math.min(p.y, h - p.y);
          if (side) this.endDrag();
          else finish(cx);
          cx.notify();
        })
        .child(top)
        .child(
          v_flex()
            .id("focus-list")
            .flex_1()
            .min_h(0)
            .px(8)
            .py(8)
            .overflow_y_scroll()
            .child(boundary("pinned", "Pinned", "pinned", pinTo(others(pinned)[0]?.address)))
            .child(gap("head-pinned"))
            .children(lane("pinned", pinned, (a) => card(a), 2))
            .child(boundary("active", "Active", "active", { section: "active" }))
            .when(dragging && others(out).length === 0 && !(out.length > 0 && !plan), (el) =>
              el.child(
                plan?.gap === "head-active" ? gap("head-active") : placeholder("active", "Active")
              )
            )
            .children(lane("active", out, (a) => card(a), 2))
            .when(out.length === 0 && !dragging, (el) =>
              el.child(
                div()
                  .px(10)
                  .py(8)
                  .text_size(12)
                  .text_color(t.dim)
                  .child(
                    every.length
                      ? "Nothing needs you."
                      : "No agent status yet. Agents show up here when they report their status."
                  )
              )
            )
            // While dragging, Settled shows even empty: it's where a drop settles.
            // The free space above the shelves pushes them to the bottom; a drag over it lands in Active, as T3's
            // nearest-row drop does.
            .child(
              div()
                .id("active-rest")
                .flex_1()
                .min_h(0)
                .on_mouse_move((_e, cx) => aim({ section: "active" }, cx))
            )
            .child(
              shelves.when(put.length > 0 || (dragging && !busy(lifted)), (el) => el.child(tail))
            )
        )
        // The lifted row moves only up and down, inside the list and below the Pinned label (T3's clamps).
        .when(Boolean(lifted) && d.y != null, (el) =>
          el.child(
            div()
              .id("drag-ghost")
              .absolute()
              .left(8)
              .right(8)
              .top(
                Math.max(
                  32 + 8 + 24,
                  Math.min(d.y - d.grab, (this.height ?? Infinity) - d.height - 8)
                )
              )
              .rounded(10)
              .bg(t.selected)
              .border(1)
              .border_color(t.accent)
              .shadow_lg()
              .child(from === "settled" ? slim(lifted, true) : card(lifted, true))
          )
        )
    );
  }
}
