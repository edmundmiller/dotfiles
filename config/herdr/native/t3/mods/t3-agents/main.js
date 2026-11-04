// Agents in grouped or priority views; parents take their most urgent sub-agent's place.
// A viewed done agent stays in Done until left.

import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import {
  agents,
  terminals,
  focused,
  run,
  theme,
  shared,
  setShared,
  setAgentOrder,
  openOverlay,
  closeOverlay,
  props,
  layout,
} from "herdr";
import { namer } from "./name.js";
const RANK = { blocked: 4, done: 3, working: 2, idle: 1 };
// A sub-agent without a pane isn't in agents(): its raw word, error counting as
// blocked. It's never done: it reports to its parent, and the parent's done is the news.
const kidStatus = (k, listed) => {
  const s = listed.get(k.address) ?? k.status;
  return s === "error" ? "blocked" : s === "done" ? "idle" : s;
};
const SORTS = [
  { id: "priority", label: "Priority", icon: "clock" },
  { id: "grouped", label: "Grouped by space", icon: "layers" },
];
const sortOf = () => SORTS.find((s) => s.id === shared("agents.sort")) ?? SORTS[0];
const SECTION = { 4: "Needs you", 3: "Done", 2: "Working", 1: "Idle" };
const SECTION_STATUS = { 4: "blocked", 3: "done", 2: "working" };

// The agent's icon from the app's program table: a one-color glyph or a picture.
function icon(p, size, color) {
  if (!p?.icon) return null;
  return p.tint
    ? svg(p.icon).size(size).flex_none().text_color(color)
    : image(p.icon).w(size).h(size).flex_none();
}

// How long it's been in its state, as the shipped agents list says it.
function duration(ms) {
  const m = Math.floor(ms / 60000);
  if (m < 1) return "<1m";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  return h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;
}

export default class Agents extends View {
  init(_props) {
    if (props()?.sortMenu) return;
    this.folded = JSON.parse(localStorage.getItem("folded") ?? "{}");
    // Each agent's last state and when it changed (ms), kept across restarts.
    this.changed = JSON.parse(localStorage.getItem("changed") ?? "{}");
    // Older installs kept pins in this list's storage; move them over once, before the focus list writes any.
    if (shared("agents.pins") == null && localStorage.getItem("pins"))
      setShared("agents.pins", JSON.parse(localStorage.getItem("pins")));
  }

  // Shared with the focus list (t3-focus): one set of pins.
  get pins() {
    return shared("agents.pins") ?? [];
  }

  isFolded(id, initial = true) {
    return this.folded[id] ?? initial;
  }

  toggleFold(id, cx, initial = true) {
    this.folded[id] = !this.isFolded(id, initial);
    localStorage.setItem("folded", JSON.stringify(this.folded));
    cx.notify();
  }

  // Stamps agents whose state changed. Done and idle count as one: looking at a
  // finished agent turns done into idle, and looking isn't the agent doing anything.
  track(list, now) {
    let dirty = false;
    for (const a of list) {
      const s = a.status === "done" ? "idle" : a.status;
      if (this.changed[a.address]?.s === s) continue;
      this.changed[a.address] = { s, at: now };
      dirty = true;
    }
    if (!dirty) return;
    // Gone and old: the list alone is empty right after a start.
    const listed = new Set(list.map((a) => a.address));
    for (const [k, c] of Object.entries(this.changed))
      if (!listed.has(k) && now - c.at > 30 * 86400000) delete this.changed[k];
    localStorage.setItem("changed", JSON.stringify(this.changed));
  }

  setPins(pins) {
    setShared("agents.pins", pins);
  }

  // Drops pins and fold choices of agents that ended. Only for machines the list has heard from:
  // right after a start, or while a machine connects, its agents aren't listed yet.
  prune(all) {
    const machine = (addr) => (addr.includes("/") ? addr.split("/")[0] : "");
    const heard = new Set(all.map((k) => machine(k.address)));
    const live = new Set(all.filter((k) => k.state === "live").map((k) => k.address));
    const kept = this.pins.filter((p) => !heard.has(machine(p)) || live.has(p));
    if (kept.length !== this.pins.length) this.setPins(kept);
    // Group headers (sp-…, sec-…, pinned) fold under the same store; only agents' entries end.
    const ended = Object.keys(this.folded).filter(
      (k) => !/^(sp-|sec-|pinned$)/.test(k) && heard.has(machine(k)) && !live.has(k)
    );
    for (const k of ended) delete this.folded[k];
    if (ended.length) localStorage.setItem("folded", JSON.stringify(this.folded));
  }

  since(a) {
    return this.changed[a.address]?.at ?? 0;
  }

  // Looking at a done agent makes it idle; it stays with Done until you leave
  // it rather than drop away under you. Any other change moves it at once.
  hold(list) {
    const cur = list.find((a) => a.focused);
    const same = cur && cur.address === this.held?.address;
    // Arriving, or any change but done turning idle, sets what it was.
    if (!same || cur.status !== "idle")
      this.held = cur ? { address: cur.address, rank: RANK[cur.status] ?? 0 } : null;
  }

  rank(a) {
    const sawDone =
      a.address === this.held?.address && this.held.rank === RANK.done && a.status === "idle";
    return sawDone ? RANK.done : (RANK[a.status] ?? 0);
  }

  sortMenu(t) {
    const on = sortOf().id;
    return v_flex()
      .w_full()
      .p(4)
      .bg(t.popover)
      .text_size(13)
      .child(div().px(8).pt(4).pb(8).text_size(11).text_color(t.dim).child("Sort agents"))
      .children(
        SORTS.map((s) =>
          h_flex()
            .id(`sort-${s.id}`)
            .h(30)
            .px(8)
            .gap(8)
            .rounded(8)
            .items_center()
            .text_color(t.foreground)
            .when(s.id === on, (el) => el.bg(t.selected))
            .when(s.id !== on, (el) => el.hover((s) => s.bg(t.hover)))
            .on_click(() => {
              setShared("agents.sort", s.id);
              closeOverlay(props().overlay);
            })
            .child(
              svg(`mods/workspace-chrome/${s.icon}.svg`).size(14).flex_none().text_color(t.muted)
            )
            .child(div().flex_1().child(s.label))
            .when(s.id === on, (el) =>
              el.child(
                svg("mods/workspace-chrome/check.svg").size(14).flex_none().text_color(t.foreground)
              )
            )
        )
      );
  }

  peek(addr) {
    run("terminal.peek", { terminal: addr });
  }

  // Live sub-agents of `addr`, depth first, each with the tree lines in front of it.
  tree(all, addr, lead = []) {
    const kids = all.filter((k) => k.parent === addr && k.state === "live");
    return kids.flatMap((k, i) => {
      const last = i === kids.length - 1;
      return [
        { t: k, depth: lead.length + 1, lines: [...lead, last ? "└" : "├"] },
        ...this.tree(all, k.address, [...lead, last ? "" : "│"]),
      ];
    });
  }

  subRow(t, s, shown) {
    const k = s.t;
    const st = kidStatus(k, this.listed);
    const pic = icon(k.program, 14, t.foreground);
    const on = k.address === shown;
    const name = k.name || k.template || k.program?.name || k.address;
    return (
      h_flex()
        .id(`sub-${k.address}`)
        .relative()
        .pl(8 + s.depth * 20)
        .pr(8)
        .rounded(8)
        .h(30)
        .flex_none()
        .items_center()
        .gap(8)
        .text_size(13)
        .role("button")
        .accessibility_label(name)
        .when(on, (el) => el.bg(t.selected))
        .when(!on, (el) => el.hover((s) => s.bg(t.hover)))
        .on_click(() => this.peek(k.address))
        // Upstream's 9px turn, hung from each ancestor's icon center (17px, then every 20px), ending 4px short of this icon.
        .children(
          s.lines.flatMap((l, j) =>
            [
              l === "│" || l === "├"
                ? div()
                    .absolute()
                    .left(16.25 + 20 * j)
                    .top(0)
                    .bottom(0)
                    .w(1.5)
                    .bg(t.input)
                : null,
              l === "├" || l === "└"
                ? div()
                    .absolute()
                    .left(16.25 + 20 * j)
                    .top(-4)
                    .h(19)
                    .w(9.75)
                    .border_l(1.5)
                    .border_b(1.5)
                    .rounded_bl(6)
                    .border_color(t.input)
                : null,
            ].filter(Boolean)
          )
        )
        .child(
          h_flex()
            .size(18)
            .flex_none()
            .items_center()
            .justify_center()
            .when(Boolean(pic), (el) => el.child(pic))
        )
        .child(
          h_flex()
            .flex_1()
            .min_w(0)
            .overflow_hidden()
            .child(
              div()
                .min_w(0)
                .truncate()
                .text_color(on ? t.foreground : t.muted)
                .child(name)
            )
        )
        .child(this.status(t, { status: st }).id(`sub-status-${k.address}`))
    );
  }

  status(t, a, note = "") {
    const color = t[a.status] ?? t.dim;
    let mark;
    if (a.status === "working")
      mark = svg("mods/workspace-chrome/spinner.svg")
        .size(12)
        .mx(1)
        .flex_none()
        .text_color(t.working)
        .spin(900);
    else if (a.status === "blocked")
      mark = div()
        .size(14)
        .flex_none()
        .rounded(4)
        .bg(t.blocked + "26")
        .text_size(11)
        .font_bold()
        .text_color(t.blocked)
        .flex()
        .items_center()
        .justify_center()
        .child("!");
    // Idle: a ring; done: a dot. Every mark is 14 wide, flush right, so the column ends where Spaces' git info does.
    else if (a.status === "idle")
      mark = div()
        .size(7)
        .mx(3.5)
        .flex_none()
        .rounded_full()
        .border(1.5)
        .border_color(t.idle ?? t.dim);
    else
      mark = div()
        .size(7)
        .mx(3.5)
        .flex_none()
        .rounded_full()
        .bg(a.status === "done" ? color : t.dim + "00");
    const label = (SECTION[RANK[a.status]] ?? "Unknown") + note;
    return h_flex()
      .size(20)
      .flex_none()
      .items_center()
      .justify_end()
      .role("status")
      .accessibility_label(label)
      .child(mark);
  }

  render(cx) {
    const t = theme();
    if (props()?.sortMenu) return this.sortMenu(t);
    const sort = sortOf();
    let list = agents();
    this.listed = new Map(list.map((a) => [a.address, a.status]));
    const all = terminals();
    const shown = focused()?.agent;
    const now = Date.now();
    this.track(list, now);
    this.hold(list);
    const byPriority = sort.id === "priority";
    const urgency = new Map(
      list.map((a) => [
        a.address,
        Math.max(
          this.rank(a),
          ...this.tree(all, a.address).map((s) => RANK[kidStatus(s.t, this.listed)] ?? 0)
        ),
      ])
    );
    const rankOf = (a) => urgency.get(a.address);
    if (byPriority)
      list = [...list].sort(
        (x, y) => rankOf(y) - rankOf(x) || this.since(y) - this.since(x) || y.seq - x.seq
      );
    this.prune(all);
    const pinned = this.pins.map((p) => list.find((a) => a.address === p)).filter(Boolean);
    const rest = list.filter((a) => !this.pins.includes(a.address));
    list = [...pinned, ...rest];
    // Only while this list shows: the focus list (t3-focus) sets its own.
    const find = (n) =>
      n?.id === "sidebar-lists" ? n : (n?.children ?? []).map(find).find(Boolean);
    if (find(layout())?.active !== "focus") setAgentOrder(list.map((a) => a.address));

    const withKids = (a, i) => {
      const subs = this.tree(all, a.address);
      const r = row(a, i, subs);
      if (!this.isFolded(a.address)) return [r, ...subs.map((s) => this.subRow(t, s, shown))];
      // Folded, a sub-agent that needs the person still shows, hung straight from its parent.
      const stuck = subs.filter((s) => kidStatus(s.t, this.listed) === "blocked");
      return [
        r,
        ...stuck.map((s, j) =>
          this.subRow(t, { t: s.t, depth: 1, lines: [j === stuck.length - 1 ? "└" : "├"] }, shown)
        ),
      ];
    };

    // A button's icon and text brighten together: a hover style reaches the text but not the svg, so it's state,
    // as in Focus. Inside a hovered row a button's own hover fill doesn't show, so this is the cue.
    const glow = (id) => (on, cx) => {
      if (on) this.hot = id;
      else if (this.hot === id) this.hot = null;
      cx.notify();
    };
    const lit = (id) => (this.hot === id ? t.foreground : t.dim);
    // As the shipped agents list: a parent's fold arrow, and folded, the count. Dim: the row's status
    // carries any hidden child's urgency.
    const fold = (a, subs) => {
      const open = !this.isFolded(a.address),
        id = `fold-${a.address}`;
      return div()
        .id(id)
        .h(20)
        .min_w(20)
        .flex_none()
        .px(4)
        .gap(3)
        .flex()
        .items_center()
        .justify_center()
        .rounded(4)
        .text_size(11)
        .role("button")
        .accessibility_label(open ? "Collapse sub-agents" : "Expand sub-agents")
        .text_color(lit(id))
        .hover((s) => s.bg(t.hover))
        .on_hover(glow(id))
        .on_click((_e, cx) => {
          cx.stop_propagation();
          this.toggleFold(a.address, cx);
        })
        .child(
          svg(`mods/workspace-chrome/chevron-${open ? "down" : "right"}.svg`)
            .size(11)
            .flex_none()
            .text_color(lit(id))
        )
        .when(!open, (el) => el.child(String(subs.length)));
    };

    // A row's detail is what the agent is on, as Focus, tabs and pane headers name it.
    const label = namer();
    const detail = new Map(list.map((a) => [a.address, /^\d+$/.test(label(a)) ? null : label(a)]));
    const seen = {};
    for (const a of list) {
      const k = `${a.space_name}\u0000${detail.get(a.address) ?? ""}`;
      seen[k] = (seen[k] ?? 0) + 1;
    }
    for (const a of list) {
      if (detail.get(a.address) == null && seen[`${a.space_name}\u0000`] > 1)
        detail.set(a.address, label(a));
    }

    const row = (a, i, subs = []) => {
      const pic = icon(a.program, 16, t.foreground);
      const more = detail.get(a.address);
      // An agent on another machine (`vps/t7`) says which.
      const machine = a.address.includes("/") ? a.address.split("/")[0] : null;
      const idle = a.status === "idle" && !a.focused;
      const isPinned = this.pins.includes(a.address);
      // Shown on hover in the time's slot, as in the shipped list; the status stays.
      const pin = div()
        .id(`pin-${a.address}`)
        .role("button")
        .size(20)
        .flex_none()
        .flex()
        .items_center()
        .justify_center()
        .rounded(4)
        .accessibility_label(isPinned ? "Unpin" : "Pin")
        .hover((s) => s.bg(t.hover))
        .on_hover(glow(`pin-${a.address}`))
        .on_click((_e, cx) => {
          cx.stop_propagation();
          // Reordering can move the row without a pointer-leave event.
          this.hovered = this.hot = null;
          this.setPins(
            isPinned ? this.pins.filter((p) => p !== a.address) : [...this.pins, a.address]
          );
          cx.notify();
        })
        .child(
          svg(`mods/workspace-chrome/${isPinned ? "pin-off" : "pin"}.svg`)
            .size(14)
            .flex_none()
            .text_color(lit(`pin-${a.address}`))
        );
      // A row leads with what the agent is on; an automatic tab number says nothing.
      // Without a space header above (priority, pinned) the space follows, dim, and gives way first.
      const full = byPriority || isPinned;
      const name = full
        ? (more ?? (a.space_name || label(a)))
        : (more ?? (/^\d+$/.test(label(a)) ? a.program?.name || label(a) : label(a)));
      const where = full && more && a.space_name && a.space_name !== more ? a.space_name : null;
      // Folded, the status shows a hidden child when it's more urgent than the agent itself.
      const folded = subs.length > 0 && this.isFolded(a.address);
      const kid = folded
        ? subs
            .map((s) => kidStatus(s.t, this.listed))
            .reduce((m, s) => ((RANK[s] ?? 0) > (RANK[m] ?? 0) ? s : m))
        : null;
      const fromKid = (RANK[kid] ?? 0) > (RANK[a.status] ?? 0);
      const when = this.since(a);
      return (
        h_flex()
          .id(`ag-${a.address}`)
          .relative()
          .w_full()
          .min_w(0)
          .px(8)
          .h(30)
          .flex_none()
          .rounded(8)
          .items_center()
          .gap(8)
          .when(a.focused, (el) => el.bg(t.selected))
          .role("button")
          .accessibility_label(label(a) || a.program?.name || a.address)
          .when(!a.focused, (el) => el.hover((s) => s.bg(t.hover)))
          .on_hover((on, cx) => {
            if (on) this.hovered = a.address;
            else if (this.hovered === a.address) this.hovered = null;
            cx.notify();
          })
          // agent.focus, not pane.focus: in tabs it focuses the pane, and it picks what the agent view shows.
          .on_click(() => run("agent.focus", { terminal: a.address }))
          .child(
            h_flex()
              .id(`agent-fold-${a.address}`)
              .size(18)
              .flex_none()
              .items_center()
              .justify_center()
              .when(subs.length > 0, (el) =>
                el
                  .accessibility_label(
                    this.isFolded(a.address) ? "Expand sub-agents" : "Collapse sub-agents"
                  )
                  .on_click((_e, cx) => {
                    cx.stop_propagation();
                    this.toggleFold(a.address, cx);
                  })
              )
              .when(Boolean(pic), (el) => el.child(pic))
          )
          .child(
            h_flex()
              .flex_1()
              .min_w(0)
              .gap(8)
              .items_center()
              .child(
                div()
                  .min_w(0)
                  .truncate()
                  .text_color(idle ? t.muted : t.foreground)
                  .child(name)
              )
              .when(Boolean(where), (el) =>
                el.child(
                  div()
                    .flex_1()
                    .flex_shrink(1000)
                    .min_w(0)
                    .truncate()
                    .text_size(12)
                    .text_color(t.dim)
                    .child(where)
                )
              )
          )
          .when(Boolean(machine), (el) =>
            el.child(div().text_size(11).text_color(t.dim).child(machine))
          )
          .child(
            h_flex()
              .id(`controls-${a.address}`)
              .flex_none()
              .items_center()
              .gap(4)
              .when(subs.length > 0, (el) => el.child(fold(a, subs)))
              // The time and the pin share one slot at least the pin's width, so hovering moves nothing else.
              .child(
                this.hovered === a.address
                  ? pin
                  : h_flex()
                      .id(`when-${a.address}`)
                      .min_w(20)
                      .flex_none()
                      .justify_end()
                      .text_size(11)
                      .text_color(t.dim)
                      .when(Boolean(when), (el) => el.child(duration(now - when)))
              )
              .child(
                this.status(t, fromKid ? { status: kid } : a, fromKid ? " (sub-agent)" : "").id(
                  `status-${a.address}`
                )
              )
          )
      );
    };

    // Groups in list order: spaces (grouped) or priority sections. Agents of a
    // space are next to each other in agents(), so neighbours make a group.
    const groups = pinned.length
      ? [{ id: "pinned", label: "Pinned", status: null, members: pinned }]
      : [];
    for (const a of rest) {
      const r = rankOf(a) || RANK.idle;
      const id = byPriority ? `sec-${r}` : `sp-${a.space}`;
      if (groups.at(-1)?.id === id) groups.at(-1).members.push(a);
      else
        groups.push({
          id,
          label: byPriority ? SECTION[r] : a.space_name || "",
          status: byPriority ? SECTION_STATUS[r] : null,
          members: [a],
        });
    }

    // A group's header; it folds the group. Folded, it says how many and the most urgent state.
    // The first group sits right under the heading, as Spaces' first row does; later ones keep 8px above.
    const header = (g, i) => {
      const initial = g.id === "sec-1";
      const open = !this.isFolded(g.id, initial);
      const top = g.members.reduce(
        (m, a) => ((RANK[a.status] ?? 0) > (RANK[m] ?? 0) ? a.status : m),
        null
      );
      return h_flex()
        .id(g.id)
        .px(8)
        .when(i > 0, (el) => el.pt(8))
        .h(i > 0 ? 30 : 22)
        .flex_none()
        .gap(4)
        .items_center()
        .text_size(11)
        .font_medium()
        .on_click((_e, cx) => this.toggleFold(g.id, cx, initial))
        .child(
          div()
            .min_w(0)
            .truncate()
            .text_color(g.status ? t[g.status] : t.dim)
            .child(g.label)
        )
        .when(byPriority || !open, (el) =>
          el.child(div().text_color(t.dim).child(String(g.members.length)))
        )
        .child(div().flex_1())
        .when(!open, (el) =>
          el
            .when(!byPriority && top && top !== "idle", (el) =>
              el.child(this.status(t, { status: top }))
            )
            .child(
              svg("mods/workspace-chrome/chevron-right.svg").size(12).flex_none().text_color(t.dim)
            )
        );
    };
    const rows = groups.flatMap((g, i) => [
      header(g, i),
      ...(this.isFolded(g.id, g.id === "sec-1") ? [] : g.members.flatMap(withKids)),
    ]);

    return v_flex()
      .id("t3-agents-root")
      .size_full()
      .min_h(0)
      .bg(t.chrome)
      .border_t(1)
      .border_color(t.border)
      .text_size(13)
      .child(
        h_flex()
          .id("agents-heading")
          .pl(16)
          .pr(10)
          .h(31)
          .flex_none()
          .items_center()
          .justify_between()
          .child(div().text_size(12).font_medium().text_color(t.muted).child("Agents"))
          .child(
            div()
              .id("ag-sort")
              .size(26)
              .flex_none()
              .flex()
              .items_center()
              .justify_center()
              .rounded(6)
              .role("button")
              .accessibility_label("Sort agents")
              .text_size(11)
              .text_color(t.dim)
              .hover((s) => s.bg(t.hover).text_color(t.foreground))
              .on_click(() =>
                openOverlay({
                  mod: "t3-agents",
                  kind: "popup",
                  width: 200,
                  height: 140,
                  props: { sortMenu: true },
                })
              )
              .child(svg(`mods/workspace-chrome/${sort.icon}.svg`).size(14))
          )
      )
      .when(list.length === 0, (el) =>
        el.child(
          div()
            .px(16)
            .text_size(12)
            .text_color(t.dim)
            .child(
              "No agent status yet. Agents show up here when they report their status. Older versions and agents inside tmux may not."
            )
        )
      )
      .child(v_flex().id("ag-list").flex_1().min_h(0).px(8).overflow_y_scroll().children(rows));
  }
}
