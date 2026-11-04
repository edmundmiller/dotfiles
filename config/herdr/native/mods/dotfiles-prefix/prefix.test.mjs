import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import vm from "node:vm";
import test from "node:test";

// Exercise keyboard events through the rendered view, without sending keys to the user's app.
async function prefixHarness(
  context = { space: "s", tab: "t", pane: "p1", terminal: "t1", cwd: "/repo" },
  machine = null,
  layout = "main"
) {
  const events = [];
  const handlers = {};
  const pending = [];
  const element = () =>
    new Proxy(
      {},
      {
        get:
          (_, name) =>
          (...args) => {
            if (name === "on_key_down") handlers.key = args[0];
            return element();
          },
      }
    );
  const cx = {
    focus_handle: () => ({ focus() {} }),
    notify() {},
    stop_propagation() {},
    spawn: (fn) => {
      pending.push(fn(cx));
    },
  };
  const modules = new Map();
  const synthetic = (name, exports) => {
    const mod = new vm.SyntheticModule(Object.keys(exports), function () {
      for (const [key, value] of Object.entries(exports)) this.setExport(key, value);
    });
    modules.set(name, mod);
  };
  synthetic("gpui-kit", { View: class {}, div: element });
  synthetic("gpui-base", { v_flex: element, h_flex: element });
  synthetic("herdr", {
    agents: () => [{ address: "a1" }, { address: "a2" }],
    closeOverlay: (id) => events.push(["close", id]),
    exec: async (...args) => {
      events.push(["exec", ...args]);
      return { code: 0 };
    },
    focused: () => context,
    hc: async (args) => {
      events.push(["hc", args]);
      return { code: 0 };
    },
    openOverlay: (args) => events.push(["overlay", args]),
    panes: () => [
      { pane: "other", tab: "elsewhere" },
      { pane: "p1", tab: "t" },
      { pane: "p2", tab: "t" },
    ],
    props: () => ({ overlay: "prefix" }),
    run: (...args) => events.push(["run", ...args]),
    shared: (key) => (key === "layout" ? layout : null),
    spaces: () => [
      {
        id: "s",
        machine,
        tabs: [
          { id: "t", index: 2 },
          { id: "t2", index: 1 },
        ],
      },
    ],
    theme: () => ({}),
    nextCommand: () => new Promise(() => {}),
  });
  for (const file of ["prefix-bindings.js", "main.js"]) {
    modules.set(
      `./${file}`,
      new vm.SourceTextModule(await readFile(new URL(file, import.meta.url), "utf8"))
    );
  }
  const main = modules.get("./main.js");
  await main.link((name) => modules.get(name));
  await main.evaluate();
  const view = new main.namespace.default();
  view.init({}, cx);
  view.render();
  return {
    events,
    view,
    async press(key, modifiers = {}, key_char = key) {
      handlers.key(
        {
          key,
          keystroke: `${modifiers.shift ? "shift-" : ""}${modifiers.alt ? "alt-" : ""}${modifiers.control ? "ctrl-" : ""}${key}`,
          key_char,
          modifiers,
        },
        cx
      );
      // The first pending task waits for mod commands indefinitely.
      await Promise.all(pending.slice(1));
    },
  };
}

test("prefix navigation, uppercase actions and tab selection dispatch native commands", async () => {
  const h = await prefixHarness();
  await h.press("h");
  await h.press("n", { shift: true }, "N");
  await h.press("3");
  await h.press("!", { shift: true });
  assert.deepEqual(h.events, [
    ["close", "prefix"],
    ["run", "pane.go", { direction: "left" }],
    ["close", "prefix"],
    ["run", "space.new", {}],
    ["close", "prefix"],
    ["run", "tab.select", { index: 3 }],
    ["close", "prefix"],
    ["run", "space.select", { index: 1 }],
  ]);
});

test("cycle wraps within this tab, not panes in other tabs", async () => {
  const h = await prefixHarness();
  await h.press("tab", { shift: true });
  assert.deepEqual(h.events, [
    ["close", "prefix"],
    ["run", "pane.focus", { pane: "p2" }],
  ]);
});

test("q cancels and legacy destructive bindings never dispatch", async () => {
  const h = await prefixHarness();
  await h.press("d");
  await h.press("d", { shift: true });
  await h.press("a");
  assert.deepEqual(h.events, []);
  await h.press("q");
  assert.deepEqual(h.events, [["close", "prefix"]]);
});

test("second Ctrl+C forwards an actual terminal interrupt before dismissing", async () => {
  const h = await prefixHarness();
  await h.press("c", { control: true });
  assert.deepEqual(h.events, [
    ["hc", ["keys", "t1", "ctrl+c"]],
    ["close", "prefix"],
  ]);
});

test("shifted punctuation opens staged Hunk review using explicit local pane", async () => {
  const h = await prefixHarness();
  await h.press("]", { shift: true }, "}");
  assert.deepEqual(h.events, [
    ["exec", "herdr-dev", ["hunk", "--pane", "p1", "--staged"], { cwd: "/repo" }],
    ["close", "prefix"],
  ]);
});

test("remote Hunk review is refused without starting a local command", async () => {
  const h = await prefixHarness(undefined, "nuc");
  await h.press("]");
  assert.deepEqual(h.events, []);
  assert.equal(h.view.message, "Hunk needs a focused local terminal pane.");
});

test("files key selects Files even when Changes was previously selected", async () => {
  const h = await prefixHarness();
  await h.press("f");
  assert.deepEqual(h.events, [
    ["close", "prefix"],
    ["run", "layout.select", { stack: "panel-body", child: "files" }],
    ["run", "layout.show", { id: "panel" }],
  ]);
});

test("T3 uppercase prefix actions are layout-scoped and preserve lowercase actions", async () => {
  const t3 = await prefixHarness(undefined, null, "herdr-t3");
  await t3.press("b", { shift: true }, "B");
  await t3.press("a", { shift: true }, "A");
  await t3.press("s", { shift: true }, "S");
  await t3.press("b");
  await t3.press("s");
  assert.deepEqual(t3.events, [
    ["close", "prefix"],
    ["run", "t3-chrome.sidebar", {}],
    ["close", "prefix"],
    ["run", "t3-tabs.view", {}],
    ["close", "prefix"],
    ["run", "t3-focus.settle", {}],
    ["close", "prefix"],
    ["run", "layout.toggle", { id: "sidebar" }],
    ["close", "prefix"],
    ["run", "pane.split", { direction: "down" }],
  ]);

  const main = await prefixHarness();
  for (const key of ["b", "a", "s"]) await main.press(key, { shift: true });
  assert.deepEqual(main.events, []);
});
