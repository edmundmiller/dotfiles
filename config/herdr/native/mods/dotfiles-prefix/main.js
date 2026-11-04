import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import {
  agents,
  closeOverlay,
  exec,
  focused,
  hc,
  openOverlay,
  panes,
  props,
  run,
  spaces,
  shared,
  theme,
  nextCommand,
} from "herdr";
import { prefixBindings, normalizePrefixKey } from "./prefix-bindings.js";

// Personal Ctrl+C prefix menu. No legacy plugins or workspace deletion commands.
export default class DotfilesPrefix extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
    this.message = "Esc cancels · Ctrl+C again sends an interrupt · q never quits";
    this.busy = false;
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand();
        if (command === "interrupt") this.activate({ special: "interrupt" }, cx);
      }
    });
  }

  dismiss() {
    closeOverlay(props().overlay);
  }

  activate(binding, cx) {
    if (this.busy) return;
    if (binding.command) {
      this.dismiss();
      run(binding.command, binding.args || {});
      return;
    }
    const context = focused();
    const space = spaces().find((item) => item.id === context?.space);
    const tab = space?.tabs.find((item) => item.id === context?.tab);
    if (binding.special === "files") {
      this.dismiss();
      run("layout.select", { stack: "panel-body", child: "files" });
      run("layout.show", { id: "panel" });
      return;
    }
    if (binding.special === "help") return;
    if (binding.special === "cancel") return this.dismiss();
    if (binding.special === "worktree") {
      this.dismiss();
      openOverlay({
        mod: "worktree",
        kind: "dialog",
        width: 620,
        height: 540,
        props: { space: context?.space, folder: context?.cwd, action: binding.action },
      });
      return;
    }
    if (binding.special === "cycle") {
      const list = panes().filter((item) => item.tab === context?.tab);
      const index = list.findIndex((item) => item.pane === context?.pane);
      if (index >= 0) {
        this.dismiss();
        run("pane.focus", { pane: list[(index + binding.step + list.length) % list.length].pane });
      }
      return;
    }
    if (binding.special === "move-tab") {
      if (tab && tab.index + binding.step >= 1 && tab.index + binding.step <= space.tabs.length) {
        this.dismiss();
        run("tab.move", { id: tab.id, index: tab.index + binding.step });
      }
      return;
    }
    if (binding.special === "agent") {
      const agent = agents()[binding.index - 1];
      if (agent) {
        this.dismiss();
        run("agent.focus", { terminal: agent.address });
      }
      return;
    }
    if (
      binding.special === "interrupt" ||
      binding.special === "hunk" ||
      binding.special === "obsidian"
    ) {
      if (binding.special === "interrupt" && !context?.terminal) return;
      if (
        binding.special === "hunk" &&
        (!context?.pane || !context.cwd || space?.machine != null)
      ) {
        this.message = "Hunk needs a focused local terminal pane.";
        cx.notify();
        return;
      }
      this.busy = true;
      cx.spawn(async (cx) => {
        try {
          const result =
            binding.special === "interrupt"
              ? await hc(["keys", context.terminal, "ctrl+c"])
              : binding.special === "hunk"
                ? await exec(
                    "herdr-dev",
                    ["hunk", "--pane", context.pane, ...(binding.args || [])],
                    { cwd: context.cwd }
                  )
                : await exec("obsidian-neovide", []);
          if (result.code !== 0) throw new Error(result.stderr || "Prefix command failed");
          this.dismiss();
        } catch (error) {
          this.message = String(error);
          this.busy = false;
          cx.notify();
        }
      });
    }
  }

  render() {
    const t = theme();
    const bindings = prefixBindings.filter(
      (item) => !item.layout || item.layout === shared("layout")
    );
    return v_flex()
      .id("dotfiles-prefix")
      .track_focus(this.handle)
      .on_key_down((event, cx) => {
        cx.stop_propagation();
        const key = normalizePrefixKey(event);
        const binding = bindings.find((item) => item.key === key);
        if (binding) this.activate(binding, cx);
        else {
          this.message = `No native binding for ${key}. Esc cancels.`;
          cx.notify();
        }
      })
      .p(16)
      .gap(8)
      .bg(t.popover)
      .text_color(t.foreground)
      .text_size(12)
      .child(div().font_semibold().text_size(15).child("Ctrl+C prefix"))
      .child(div().text_color(t.muted).child(this.message))
      .child(
        v_flex()
          .max_h(440)
          .overflow_y_scrollbar()
          .children(
            bindings
              .filter((item) => item.label)
              .map((item) =>
                h_flex()
                  .id(`prefix-${item.key}`)
                  .gap(12)
                  .p(4)
                  .cursor_pointer()
                  .hover((style) => style.bg(t.hover))
                  .on_click((_event, cx) => this.activate(item, cx))
                  .child(div().w(100).text_color(t.accent).child(item.key))
                  .child(div().child(item.label))
              )
          )
      )
      .child(
        div()
          .text_color(t.dim)
          .child("Legacy-only actions are not mapped. Native shortcuts still work.")
      );
  }
}
