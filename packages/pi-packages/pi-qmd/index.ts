/** QMD extension entrypoint. Wires runtime hooks, commands, and scoped init tool. */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { register_qmd_command } from "./extension/command.js";
import { type QmdExtensionState, register_runtime } from "./extension/runtime.js";
import { register_qmd_tool } from "./extension/tool.js";

export default function qmd_extension(pi: ExtensionAPI) {
  const state: QmdExtensionState = {};

  register_runtime(pi, state);
  register_qmd_tool(pi, state);
  register_qmd_command(pi, state);
}
