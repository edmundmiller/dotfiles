/**
 * DCP Init Command
 *
 * Generate a default dcp.config.ts file in the current directory.
 */

import type { ExtensionCommandContext } from "@mariozechner/pi-coding-agent";
import { writeConfigFile } from "../config";
import { join } from "path";
import { CommandDefinition } from "../types";

export function createInitCommand(): CommandDefinition {
  return {
    description: "Generate a default dcp.config.ts file in the current directory",
    handler: async (args, ctx) => {
      const configPath = join(process.cwd(), "dcp.config.ts");
      const force = args?.toLowerCase() === "--force";

      try {
        await writeConfigFile(configPath, { force });
        ctx.ui.notify(`Config file created: ${configPath}`, "info");
      } catch (error: any) {
        if (error.message?.includes("already exists")) {
          ctx.ui.notify(
            "Config file already exists. Use '/dcp-init --force' to overwrite.",
            "warning"
          );
        } else {
          ctx.ui.notify(`Failed to create config file: ${error.message || error}`, "error");
        }
      }
    },
  };
}
