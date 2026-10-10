import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

import { createLazyActivation } from "./_lib/lazy-extension.mjs";

const COMMANDS = new Map([
  ["plannotator-plan-mode", "Toggle plannotator planning mode"],
  [
    "plannotator-review",
    "Open interactive code review for current changes or a PR URL; pass --git or --gitbutler to force that provider",
  ],
  ["plannotator-annotate", "Open markdown file or folder in annotation UI"],
  ["plannotator-last", "Annotate the last assistant message"],
]);

function pluginEntry() {
  const configDirectory = process.env.PI_CONFIG_DIR || ".omp";
  return join(
    homedir(),
    configDirectory,
    "plugins",
    "node_modules",
    "@plannotator",
    "pi-extension",
    "omp-lazy-bundle.js"
  );
}

async function importPlannotator() {
  const [piAi, piTui] = await Promise.all([
    import("@earendil-works/pi-ai"),
    import("@earendil-works/pi-tui"),
  ]);
  globalThis.__dotfilesOmpLazyPluginHost = {
    ...globalThis.__dotfilesOmpLazyPluginHost,
    Key: piTui.Key,
    Type: piAi.Type,
  };
  return import(pathToFileURL(pluginEntry()).href);
}

export function createLazyPlannotator(importExtension = importPlannotator) {
  return async function lazyPlannotator(api) {
    const lazy = createLazyActivation({
      api,
      captureCommands: [...COMMANDS.keys()],
      importExtension,
      replayEvents: ["session_start"],
    });

    // Inbox must register its tool and reply wake before the first agent turn.
    api.on("session_start", async (event, context) => {
      if (!lazy.isActivated() && process.env.PLANNOTATOR_INBOX_TOOL === "1") {
        await lazy.activate(context);
        return;
      }
      if (lazy.isActivated()) return lazy.emit("session_start", event, context);
    });

    for (const [name, description] of COMMANDS) {
      api.registerCommand(name, {
        description,
        async handler(args, context) {
          await lazy.activate(context);
          const command = lazy.commands.get(name);
          if (!command) {
            throw new Error(`Plannotator did not register /${name}`);
          }
          await command.handler(args, context);
        },
      });
    }
  };
}

export default createLazyPlannotator();
