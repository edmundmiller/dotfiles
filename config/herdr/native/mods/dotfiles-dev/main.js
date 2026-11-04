import { View, div } from "gpui-kit";
import { v_flex } from "gpui-base";
import { exec, focused, pickFolder, spaces, theme } from "herdr";

// Native dev tools run local commands only. Remote spaces require remote helpers.
export default class DotfilesDev extends View {
  init() {
    this.busy = false;
    this.message = "";
  }

  launch(args, cx) {
    if (this.busy) return;
    const context = focused();
    const space = spaces().find((item) => item.id === context?.space);
    if (space?.machine != null) {
      this.message = "Dev tools currently support local spaces only.";
      cx.notify();
      return;
    }
    const cwd = context?.cwd;
    if (args[0] === "hunk" && (!context?.pane || !cwd)) {
      this.message = "Focus a local terminal pane before opening a review.";
      cx.notify();
      return;
    }
    const commandArgs =
      args[0] === "hunk" ? ["hunk", "--pane", context.pane, ...args.slice(1)] : args;
    this.busy = true;
    this.message = "Opening...";
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        let command = commandArgs;
        if (args[0] === "open") {
          const folder = await pickFolder({ prompt: "Open a Git checkout" });
          if (!folder) return;
          command = ["open", folder, ...args.slice(1)];
        }
        const result = await exec("herdr-dev", command, { cwd: cwd || undefined });
        this.message =
          result.code === 0 ? "Opened." : result.stderr.trim() || "Dev command failed.";
      } catch (error) {
        this.message = String(error);
      } finally {
        this.busy = false;
        if (this.message === "Opening...") this.message = "";
        cx.notify();
      }
    });
  }

  render() {
    const t = theme();
    const button = (id, label, args) =>
      div()
        .id(id)
        .p(8)
        .rounded(4)
        .bg(t.raised)
        .text_color(t.foreground)
        .cursor_pointer()
        .hover((style) => style.bg(t.hover))
        .on_click((_event, cx) => this.launch(args, cx))
        .child(label);
    return v_flex()
      .p(16)
      .gap(8)
      .text_size(13)
      .bg(t.surface)
      .child(div().font_semibold().text_color(t.foreground).child("Dev tools"))
      .child(button("dev-pi", "Open checkout with Pi + Hunk", ["open", "--agent", "pi"]))
      .child(button("dev-omp", "Open checkout with OMP + Hunk", ["open", "--agent", "omp"]))
      .child(button("dev-hunk", "Review current checkout", ["hunk"]))
      .child(button("dev-hunk-staged", "Review staged changes", ["hunk", "--staged"]))
      .child(
        div()
          .text_color(t.muted)
          .child(this.message || "Safe jj removal stays in the legacy workflow.")
      );
  }
}
