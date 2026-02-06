/**
 * DCP Toggle Command
 *
 * Enable or disable the DCP extension.
 */

import type { CommandDefinition, DcpConfig } from "../types";

export function createToggleCommand(config: DcpConfig): CommandDefinition {
  return {
    description: "Toggle DCP on/off",
    handler: async (args, ctx) => {
      config.enabled = !config.enabled;
      ctx.ui.notify(`DCP: ${config.enabled ? "ENABLED" : "DISABLED"}`, "info");
    },
  };
}
