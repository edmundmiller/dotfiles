// Workspace spaces: stable colored avatars, worktrees under their checkout,
// grouped by machine when more than one is known. After a space's name, the repo
// its first terminal is in now, only where unusual: branch, ahead/behind. Agent state lives in the agents list, not here. Click to
// switch, right-click for its menu, drag to reorder.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import {
  spaces,
  agents,
  machines,
  panes,
  layout,
  run,
  openOverlay,
  exec,
  hc,
  theme,
  shared,
  setShared,
  watchFolder,
  window,
} from "herdr";

// Where a space is now: its first terminal's live folder, else where it was made.
// `ps`: panes(), read once by the caller (each read copies every pane).
function place(s, ps) {
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return ps.find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}
const where = (s, ps) => JSON.stringify([s.machine ?? null, place(s, ps)]);
const base = (path) => path.replace(/\/+$/, "").split("/").pop();

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}
// The agent view keeps the space of the agent it shows, so space.select alone changes nothing there:
// show this space's agent (its active tab's first), or the tabs when it has none.
function select(s) {
  if (find(layout(), "view")?.active === "agent") {
    const tab = s.tabs.find((c) => c.active)?.id,
      mine = agents().filter((a) => a.space === s.id);
    const a = mine.find((a) => a.tab === tab) ?? mine[0];
    if (a) return run("agent.focus", { terminal: a.address });
    run("layout.select", { stack: "view", child: "main" });
  }
  run("space.select", { id: s.id });
}
// Changes made outside Herdr (an editor's save, a commit in another app): looked
// for this often, in repos the list shows, while the window is in front.
const FALLBACK = 60000;

// What a stored color name looks like on an avatar (the same in every mod
// that draws space avatars): one strong color per hue, light and dark alike.
const MARK = {
  ansi6: "#22a99a",
  ansi3: "#e3814f",
  ansi4: "#5b8def",
  ansi5: "#8b7cf6",
  ansi2: "#3fae6a",
  ansi1: "#d9649a",
};

export default class Spaces extends View {
  init(_props, cx) {
    this.git = {}; // where() -> { name, branch, ahead, behind, repo, linked }, null: not a repo
    this.checked = {}; // where() -> when it was last looked at
    this.unsure = new Set(); // where()s git couldn't answer for (a machine away)
    this.pending = new Set(); // where()s to look at next
    this.busy = {}; // pane -> an agent working or a program in front of its shell
    this.ready = {}; // machine -> its layout was readable at the last look
    this.at = {}; // space -> its where() at the last look
    this.watching = new Set(); // local repos' git folders
    // Spaces made while this runs wait (at most a moment) for their git, so a
    // worktree appears under its repo instead of jumping there.
    this.shown = new Set(spaces().map((s) => s.id));
    this.born = {};
    this.pressed = null;
    this.over = null;
    this.machines = [];
    this.folded = new Set(JSON.parse(localStorage.getItem("machines.folded") ?? "[]"));
    this.foldedRepos = new Set(JSON.parse(localStorage.getItem("repos.folded") ?? "[]"));
    this.refreshMachines(cx);
    cx.timer.every(15000, (cx) => this.refreshMachines(cx));
    // `git status` walks the whole tree, on another machine a process there:
    // only when its answer could have changed (see `due`).
    cx.timer.every(250, (cx) => this.checkNew(cx));
  }

  checkNew(cx) {
    const now = Date.now();
    const sp = spaces();
    for (const s of sp) if (!this.shown.has(s.id)) this.born[s.id] ??= now;
    const due = this.due(now, sp, panes());
    if (due.size) this.refreshGit(due, cx);
    if (sp.some((s) => !this.shown.has(s.id))) cx.notify();
  }

  // Places whose git could have changed: new ones (a new space, a cd), where a
  // command or an agent's turn just ended (a checkout, a commit, edits), those on
  // a machine that is back, and repos in view whose fallback is due.
  due(now, sp, ps) {
    // Moved there: what it knew of that place may be old.
    const at = {};
    for (const s of sp) at[s.id] = where(s, ps);
    const keys = new Set(Object.values(at).filter((k) => JSON.parse(k)[1]));
    const due = new Set([...keys].filter((k) => !(k in this.git)));
    for (const [id, k] of Object.entries(at))
      if (this.at[id] && this.at[id] !== k && keys.has(k)) due.add(k);
    this.at = at;
    const spaceOf = {};
    for (const s of sp) for (const t of s.tabs ?? []) spaceOf[t.id] = s;
    const busy = {};
    for (const p of ps) {
      if (!p.terminal || !spaceOf[p.tab]) continue;
      busy[p.pane] = p.status === "working" || !(p.program?.shell || p.program?.agent);
      if (this.busy[p.pane] && !busy[p.pane])
        this.sameRepo(at[spaceOf[p.tab].id], keys).forEach((k) => due.add(k));
    }
    this.busy = busy;
    for (const m of machines()) {
      const ready = m.layout === "ready";
      if (ready && this.ready[m.name] === false)
        for (const k of keys) if (JSON.parse(k)[0] === m.name) due.add(k);
      this.ready[m.name] = ready;
    }
    if (window().active) {
      for (const k of keys) {
        const asks = this.git[k] || this.unsure.has(k);
        if (asks && !this.folded.has(JSON.parse(k)[0]) && now - (this.checked[k] ?? 0) > FALLBACK)
          due.add(k);
      }
    }
    return due;
  }

  // `key` and the other places in its repo (a commit there moves their ahead/behind).
  sameRepo(key, keys) {
    const repo = this.git[key]?.repo;
    return [key, ...(repo ? [...keys].filter((k) => this.git[k]?.repo === repo) : [])];
  }

  refreshMachines(cx) {
    cx.spawn(async (cx) => {
      try {
        const r = await hc(["machine", "ls", "--json"]);
        if (r.code === 0)
          this.machines = (JSON.parse(r.stdout).machines ?? []).filter((m) => !m.temporary);
      } catch {}
      cx.notify();
    });
  }

  // One look at a time, each place once however often it was asked for meanwhile.
  refreshGit(keys, cx) {
    for (const k of keys) this.pending.add(k);
    if (this.refreshing) return;
    this.refreshing = true;
    cx.spawn(async (cx) => {
      while (this.pending.size) {
        const keys = [...this.pending];
        this.pending.clear();
        for (const key of keys) await this.check(key, cx);
      }
      const used = new Set(
        Object.values(this.git)
          .filter(Boolean)
          .map((g) => JSON.parse(g.repo))
          .filter(([on]) => !on)
          .map(([, repo]) => repo)
      );
      for (const repo of this.watching) if (!used.has(repo)) this.watching.delete(repo);
      this.refreshing = false;
      cx.notify();
    });
  }

  // One place's git: branch, ahead/behind, its repo.
  async check(key, cx) {
    const [on, cwd] = JSON.parse(key);
    this.checked[key] = Date.now();
    this.unsure.delete(key);
    try {
      // No optional locks: a status that touched the index would wake the watch again.
      // Writes nothing under .git (index lock, fsmonitor cookie): watch() would wake on it.
      const r = await exec(
        "git",
        [
          "--no-optional-locks",
          "-c",
          "core.fsmonitor=false",
          "status",
          "--porcelain=v2",
          "--branch",
        ],
        { cwd, on }
      );
      if (r.code !== 0) {
        // Only git's own "no" is remembered as no repo; anything else is asked again.
        if (!/not a git repository/i.test(r.stderr)) this.unsure.add(key);
        this.git[key] = null;
        return;
      }
      // The repo's own .git folder names it; a worktree's top differs from it.
      const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd, on });
      const common = await exec(
        "git",
        ["rev-parse", "--path-format=absolute", "--git-common-dir"],
        { cwd, on }
      );
      const repo = common.stdout.trim();
      const name = repo.endsWith("/.git")
        ? base(repo.slice(0, -5))
        : base(repo).replace(/\.git$/, "");
      const info = {
        name,
        branch: null,
        ahead: 0,
        behind: 0,
        repo: JSON.stringify([on, repo]),
        linked: repo !== `${top.stdout.trim()}/.git`,
      };
      for (const line of r.stdout.split("\n")) {
        if (line.startsWith("# branch.head ")) info.branch = line.slice(14);
        else if (line.startsWith("# branch.ab ")) {
          const [a, b] = line.slice(12).split(" ");
          info.ahead = Math.abs(parseInt(a, 10)) || 0;
          info.behind = Math.abs(parseInt(b, 10)) || 0;
        }
      }
      this.git[key] = info;
      if (!on) this.watch(repo, cx);
    } catch {
      // Couldn't ask (the machine is away): keep what it showed, look again later.
      this.git[key] ??= null;
      this.unsure.add(key);
    }
  }

  watch(repo, cx) {
    if (this.watching.has(repo)) return;
    this.watching.add(repo);
    cx.spawn(async (cx) => {
      try {
        while (this.watching.has(repo)) {
          await watchFolder(repo);
          const mine = JSON.stringify([null, repo]);
          if (this.watching.has(repo))
            this.refreshGit(
              Object.keys(this.git).filter((k) => this.git[k]?.repo === mine),
              cx
            );
        }
      } catch {
        this.watching.delete(repo);
      }
    });
  }

  menu(w) {
    // A popup is as tall as its items; height is only the most.
    openOverlay({
      mod: "menu",
      kind: "popup",
      width: 200,
      height: 260,
      props: { tab: "space", target: { id: w.id } },
    });
  }

  // Spaces in order, each worktree space moved under its main checkout's.
  ordered() {
    const sp = spaces(),
      ps = panes();
    const ready = (w) =>
      this.shown.has(w.id) ||
      where(w, ps) in this.git ||
      Date.now() - (this.born[w.id] ??= Date.now()) > 1500;
    for (const w of sp) if (!this.shown.has(w.id) && ready(w)) this.shown.add(w.id);
    const list = sp
      .map((w, i) => ({ w, i, g: this.git[where(w, ps)] ?? null }))
      .filter((r) => this.shown.has(r.w.id));
    const mains = new Set(list.filter((r) => r.g && !r.g.linked).map((r) => r.g.repo));
    const nested = (r) => r.g?.linked && mains.has(r.g.repo);
    const out = [];
    const placed = new Set(); // repos whose worktrees are listed (under the first of its spaces)
    for (const r of list) {
      if (nested(r)) continue;
      const top = { ...r, tree: null, kids: 0 };
      out.push(top);
      if (!r.g || r.g.linked || placed.has(r.g.repo)) continue;
      placed.add(r.g.repo);
      const kids = list.filter((k) => nested(k) && k.g.repo === r.g.repo);
      top.kids = kids.length;
      if (this.foldedRepos.has(r.g.repo)) continue;
      kids.forEach((k, n) => out.push({ ...k, tree: n === kids.length - 1 ? "└─" : "├─" }));
    }
    return out;
  }

  toggleRepo(repo, cx) {
    this.foldedRepos.has(repo) ? this.foldedRepos.delete(repo) : this.foldedRepos.add(repo);
    localStorage.setItem("repos.folded", JSON.stringify([...this.foldedRepos]));
    cx.notify();
  }

  // The rows, under a header per machine once one isn't this computer.
  grouped(t) {
    const rows = this.ordered();
    const draw = (r) => this.row(r, t);
    const remote = [
      ...new Set([
        ...rows.map((r) => r.w.machine).filter(Boolean),
        ...this.machines.map((m) => m.name),
      ]),
    ].sort();
    const loading = (m) => {
      const layout = machines().find((k) => k.name === m)?.layout;
      return (
        layout === "loading" ||
        (!layout && this.machines.some((k) => k.name === m && k.state === "connected")) ||
        spaces().some((s) => (s.machine ?? null) === m && !this.shown.has(s.id))
      );
    };
    const loadingRow = (m) =>
      div()
        .id(`machine-loading-${m ?? "local"}`)
        .h(30)
        .flex_none()
        .px(8)
        .text_size(13)
        .text_color(t.dim)
        .child("Loading…");
    if (!remote.length) return loading(null) && !rows.length ? [loadingRow(null)] : rows.map(draw);
    const machineNames = [null, ...remote];
    return machineNames.flatMap((m, i) => {
      const mine = rows.filter((r) => (r.w.machine ?? null) === m);
      const machine = this.machines.find((k) => k.name === m);
      const connected = !m || machine?.state === "connected";
      const folded = this.folded.has(m);
      // Drawn as the agents list's group headers: the first under the heading, later ones 8px apart.
      const head = h_flex()
        .id(`machine-${m ?? "local"}`)
        .when(i > 0, (el) => el.pt(8))
        .h(i > 0 ? 30 : 22)
        .flex_none()
        .px(8)
        .gap(4)
        .items_center()
        .text_size(11)
        .font_medium()
        .text_color(t.dim)
        .on_click((_e, cx) => {
          folded ? this.folded.delete(m) : this.folded.add(m);
          localStorage.setItem("machines.folded", JSON.stringify([...this.folded]));
          cx.notify();
        })
        .child(
          svg(`mods/workspace-chrome/${m ? "server" : "monitor"}.svg`)
            .size(14)
            .flex_none()
        )
        .child(
          div()
            .flex_1()
            .min_w(0)
            .truncate()
            .child(m ?? "This computer")
        )
        .when(!connected, (el) =>
          el.child(
            div()
              .flex_none()
              .child((machine?.state ?? "asleep").replace(/_/g, " "))
          )
        )
        .when(connected, (el) =>
          el.child(
            div()
              .id(`machine-add-${m ?? "local"}`)
              .size(20)
              .flex_none()
              .flex()
              .items_center()
              .justify_center()
              .rounded(4)
              .role("button")
              .accessibility_label("New space here")
              .hover((s) => s.bg(t.hover).text_color(t.foreground))
              .on_click((_e, cx) => {
                cx.stop_propagation();
                run("space.new", m ? { machine: m } : {});
              })
              .child(svg("mods/workspace-chrome/plus.svg").size(12))
          )
        )
        .child(
          div()
            .size(6)
            .rounded_full()
            .flex_none()
            .bg(connected ? t.ansi2 : t.dim)
        )
        .child(
          svg(`mods/workspace-chrome/chevron-${folded ? "right" : "down"}.svg`)
            .size(12)
            .flex_none()
        );
      const empty = h_flex()
        .id(`machine-new-${m ?? "local"}`)
        .h(30)
        .flex_none()
        .px(8)
        .gap(8)
        .items_center()
        .rounded(8)
        .text_size(13)
        .text_color(t.dim)
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_click(() => run("space.new", m ? { machine: m } : {}))
        .child(svg("mods/workspace-chrome/plus.svg").size(12))
        .child("New space there");
      return [
        head,
        ...(folded ? [] : mine.length ? mine.map(draw) : [loading(m) ? loadingRow(m) : empty]),
      ];
    });
  }

  // Only what's unusual, after the name: "herdr \u00b7 spike \u21912 \u21931". The repo or
  // branch goes when the name already says it (a worktree is named after its branch),
  // and master/main go: nearly every space is on one.
  gitTail(g, tree, name, t) {
    const raw = g.branch ?? "detached";
    const same = (a) => a.toLowerCase() === name.toLowerCase();
    const branch = same(raw) || raw === "master" || raw === "main" ? "" : raw;
    const repo = tree || same(g.name) ? "" : g.name;
    const where = [repo, branch].filter(Boolean).join(" \u00b7 ");
    return h_flex()
      .flex_1()
      .min_w(0)
      .gap(4)
      .justify_end()
      .items_center()
      .text_size(11)
      .text_color(t.dim)
      .when(Boolean(where), (el) => el.child(div().min_w(0).truncate().child(where)))
      .when(g.ahead > 0, (el) =>
        el.child(div().flex_none().text_color(t.ansi2).child(`\u2191${g.ahead}`))
      )
      .when(g.behind > 0, (el) =>
        el.child(div().flex_none().text_color(t.ansi1).child(`\u2193${g.behind}`))
      );
  }

  row({ w, i, g, tree, kids = 0 }, t) {
    const on = w.active;
    const colors = shared("space.colors") ?? {};
    const color = colors[w.id] ?? "ansi6";
    const fill = color.startsWith("#") ? color : (MARK[color] ?? t[color]);
    // A checkout with worktrees folds them as an agent folds its sub-agents: hovered, its
    // avatar turns into the arrow; folded, a dim count at the end says how many and opens them.
    const folded = kids > 0 && this.foldedRepos.has(g.repo);
    const stop = (_e, cx) => cx.stop_propagation();
    const toggle = (_e, cx) => {
      cx.stop_propagation();
      this.toggleRepo(g.repo, cx);
    };
    return (
      v_flex()
        .relative()
        .id(`space-${w.id}`)
        .px(8)
        .h(30)
        .flex_none()
        .justify_center()
        .rounded(8)
        .role("button")
        .accessibility_label(w.name)
        .when(on, (el) => el.bg(t.selected))
        .when(!on, (el) => el.hover((s) => s.bg(t.hover)))
        .when(kids > 0, (el) =>
          el.on_hover((over, cx) => {
            if (over) this.hovered = w.id;
            else if (this.hovered === w.id) this.hovered = null;
            cx.notify();
          })
        )
        .when(this.pressed === i && this.over !== i, (el) => el.opacity(0.5))
        .when(this.pressed !== null && this.over === i && this.pressed !== i, (el) =>
          el.child(
            div()
              .absolute()
              .left(0)
              .right(0)
              .h(2)
              .bg(t.accent)
              .when(this.pressed < i, (line) => line.bottom(0))
              .when(this.pressed > i, (line) => line.top(0))
          )
        )
        .on_mouse_down("left", () => {
          this.pressed = i;
          this.over = i;
        })
        .on_mouse_move((_e, cx) => {
          const source = spaces()[this.pressed];
          const over = source && (source.machine ?? null) === (w.machine ?? null) ? i : null;
          if (this.pressed !== null && this.over !== over) {
            this.over = over;
            cx.notify();
          }
        })
        .on_mouse_up("left", (_e, cx) => {
          const from = this.pressed;
          const over = this.over;
          this.pressed = null;
          this.over = null;
          if (from !== null && over === i && from !== i)
            run("space.move", { id: spaces()[from].id, index: i + 1 });
          else if (from === i) select(w);
          cx.notify();
        })
        .on_mouse_down("right", () => this.menu(w))
        // The same tree lines as sub-agents: from the checkout's avatar center, turning into the branch icon.
        .when(tree === "├─", (el) =>
          el.child(div().absolute().left(16.25).top(0).bottom(0).w(1.5).bg(t.input))
        )
        .when(Boolean(tree), (el) =>
          el.child(
            div()
              .absolute()
              .left(16.25)
              .top(-4)
              .h(19)
              .w(9.75)
              .border_l(1.5)
              .border_b(1.5)
              .rounded_bl(6)
              .border_color(t.input)
          )
        )
        .child(
          h_flex()
            .w_full()
            .min_w(0)
            .gap(8)
            .items_center()
            .when(Boolean(tree), (el) =>
              el
                .pl(20)
                .child(
                  h_flex()
                    .size(18)
                    .flex_none()
                    .items_center()
                    .justify_center()
                    .child(svg("mods/workspace-chrome/branch.svg").size(16).text_color(t.dim))
                )
            )
            .when(!tree && kids > 0 && this.hovered === w.id, (el) =>
              el.child(
                h_flex()
                  .id(`space-fold-${w.id}`)
                  .size(18)
                  .flex_none()
                  .items_center()
                  .justify_center()
                  .role("button")
                  .accessibility_label(folded ? "Expand worktrees" : "Collapse worktrees")
                  .on_mouse_down("left", stop)
                  .on_click(toggle)
                  .child(
                    svg(`mods/workspace-chrome/chevron-${folded ? "right" : "down"}.svg`)
                      .size(12)
                      .text_color(t.foreground)
                  )
              )
            )
            .when(!tree && !(kids > 0 && this.hovered === w.id), (el) =>
              el.child(
                h_flex()
                  .size(18)
                  .flex_none()
                  .rounded(5)
                  .bg(fill)
                  .items_center()
                  .justify_center()
                  .text_size(11)
                  .font_bold()
                  .text_color("#ffffff")
                  .child([...w.name][0]?.toUpperCase() ?? "?")
              )
            )
            .child(div().min_w(0).max_w(150).truncate().text_color(t.foreground).child(w.name))
            .child(g ? this.gitTail(g, tree, w.name, t) : div().flex_1())
            .when(folded, (el) =>
              el.child(
                div()
                  .id(`space-count-${w.id}`)
                  .h(20)
                  .min_w(20)
                  .px(4)
                  .flex_none()
                  .flex()
                  .items_center()
                  .justify_center()
                  .rounded(4)
                  .text_size(11)
                  .text_color(t.dim)
                  .hover((s) => s.bg(t.hover).text_color(t.foreground))
                  .role("button")
                  .accessibility_label("Expand worktrees")
                  .on_mouse_down("left", stop)
                  .on_click(toggle)
                  .child(String(kids))
              )
            )
        )
    );
  }

  render() {
    const t = theme();
    const palette = ["ansi6", "ansi3", "ansi4", "ansi5", "ansi2", "ansi1"];
    const sp = spaces();
    const ids = new Set(sp.map((p) => p.id));
    const kept = Object.fromEntries(
      Object.entries(shared("space.colors") ?? {}).filter(([id]) => ids.has(id))
    );
    let changed = Object.keys(kept).length !== Object.keys(shared("space.colors") ?? {}).length;
    for (const p of sp) {
      if (kept[p.id] || p.name === "~") continue;
      const uses = (c) => Object.values(kept).filter((v) => v === c).length;
      kept[p.id] = palette.reduce((best, c) => (uses(c) < uses(best) ? c : best));
      changed = true;
    }
    if (changed) setShared("space.colors", kept);
    return v_flex()
      .size_full()
      .min_h(0)
      .bg(t.chrome)
      .text_size(13)
      .child(
        h_flex()
          .id("spaces-heading")
          .h(32)
          .flex_none()
          .pl(16)
          .pr(10)
          .items_center()
          .justify_between()
          .text_size(12)
          .font_medium()
          .text_color(t.dim)
          .child(div().text_color(t.muted).child("Spaces"))
          .child(
            div()
              .id("space-new")
              .size(26)
              .flex_none()
              .flex()
              .items_center()
              .justify_center()
              .rounded(6)
              .role("button")
              .accessibility_label("New space")
              .hover((s) => s.bg(t.hover).text_color(t.foreground))
              .on_click(() => run("space.new"))
              .child(svg("mods/workspace-chrome/plus.svg").size(14))
          )
      )
      .child(
        v_flex()
          .id("space-list")
          .flex_1()
          .min_h(0)
          .overflow_y_scroll()
          .on_mouse_up("left", (_e, cx) => {
            this.pressed = null;
            cx.notify();
          })
          .child(
            v_flex().id("space-content").w_full().flex_none().px(8).pb(8).children(this.grouped(t))
          )
      );
  }
}
