import { existsSync, readFileSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

import { createLazyActivation } from "./lib/lazy-extension";

const COMMANDS = new Map([
  ["plannotator", "Toggle plannotator planning mode"],
  [
    "plannotator-review",
    "Open interactive code review for current changes or a PR URL; pass --git or --gitbutler to force that provider",
  ],
  ["plannotator-annotate", "Open markdown file or folder in annotation UI"],
  ["plannotator-last", "Annotate the last assistant message"],
]);
const PLAN_SHORTCUT = "ctrl+alt+p";
const PLAN_TOOL = "plannotator_submit_plan";

function piAgentRoot() {
  return process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
}

function packageRoot() {
  return join(piAgentRoot(), "npm", "node_modules", "@plannotator", "pi-extension");
}

function buildLazyBundle(root: string, output: string) {
  const entry = join(root, `dotfiles-pi-lazy-entry-${process.pid}.ts`);
  const temporaryOutput = join(root, `dotfiles-pi-lazy-bundle-${process.pid}.js`);
  const source = readFileSync(join(root, "index.ts"), "utf8");
  const typeImport = 'import { Type } from "@earendil-works/pi-ai";';
  const keyImport = 'import { Key } from "@earendil-works/pi-tui";';
  if (!source.includes(typeImport) || !source.includes(keyImport)) {
    throw new Error("Plannotator entrypoint imports changed; cannot build the lazy Pi bundle");
  }

  writeFileSync(
    entry,
    source
      .replace(typeImport, "const { Type } = globalThis.__dotfilesPiLazyPluginHost;")
      .replace(keyImport, "const { Key } = globalThis.__dotfilesPiLazyPluginHost;")
  );

  try {
    const result = spawnSync(
      "bun",
      [
        "build",
        entry,
        "--outfile",
        temporaryOutput,
        "--target",
        "bun",
        "--external",
        "@anthropic-ai/claude-agent-sdk",
        "--external",
        "@earendil-works/pi-agent-core",
        "--external",
        "@earendil-works/pi-coding-agent",
        "--external",
        "@opencode-ai/sdk",
      ],
      { cwd: root, encoding: "utf8" }
    );
    if (result.status !== 0) {
      throw new Error(result.stderr.trim() || "bun build failed");
    }
    renameSync(temporaryOutput, output);
  } finally {
    for (const path of [entry, temporaryOutput]) {
      if (existsSync(path)) unlinkSync(path);
    }
  }
}

async function importPlannotator() {
  const root = packageRoot();
  const output = join(root, "pi-lazy-bundle.js");
  if (!existsSync(output)) buildLazyBundle(root, output);

  const [piAi, piTui] = await Promise.all([
    import("@earendil-works/pi-ai"),
    import("@earendil-works/pi-tui"),
  ]);
  Reflect.set(globalThis, "__dotfilesPiLazyPluginHost", {
    Key: piTui.Key,
    Type: piAi.Type,
  });
  return import(pathToFileURL(output).href);
}

export function createLazyPlannotator(importExtension = importPlannotator) {
  return async function lazyPlannotator(api: Parameters<typeof createLazyActivation>[0]["api"]) {
    const lazy = createLazyActivation({
      api,
      captureCommands: [...COMMANDS.keys()],
      captureFlags: ["plan"],
      captureShortcuts: [PLAN_SHORTCUT],
      captureTools: [PLAN_TOOL],
      importExtension,
      replayEvents: ["session_start"],
    });

    api.registerFlag("plan", {
      description: "Start in plan mode (restricted exploration and planning)",
      type: "boolean",
      default: false,
    });

    for (const [name, description] of COMMANDS) {
      api.registerCommand(name, {
        description,
        async handler(args: unknown, context: unknown) {
          await lazy.activate(context);
          const command = lazy.commands.get(name);
          if (!command) throw new Error(`Plannotator did not register /${name}`);
          return command.handler(args, context);
        },
      });
    }

    api.registerShortcut(PLAN_SHORTCUT, {
      description: "Toggle plannotator",
      async handler(context: unknown) {
        await lazy.activate(context);
        const shortcut = lazy.shortcuts.get(PLAN_SHORTCUT);
        if (!shortcut) throw new Error("Plannotator did not register Ctrl+Alt+P");
        return shortcut.handler(context);
      },
    });

    api.registerTool({
      name: PLAN_TOOL,
      label: "Submit Plan",
      description:
        "Submit your Plannotator plan for user review. Call this only while Plannotator planning mode is active, after writing your plan as a markdown file anywhere inside the working directory. Pass the path to the plan file (e.g. PLAN.md or plans/auth.md). The user will review the plan in a visual browser UI and can approve, deny with feedback, or annotate it. If denied, edit the same file in place, then call this again with the same path.",
      parameters: {
        type: "object",
        properties: {
          filePath: {
            type: "string",
            description:
              "Path to the markdown plan file, relative to the working directory. Must end in .md or .mdx and resolve inside cwd.",
          },
        },
        required: ["filePath"],
        additionalProperties: false,
      },
      async execute(
        toolCallId: unknown,
        params: unknown,
        signal: unknown,
        onUpdate: unknown,
        context: unknown
      ) {
        await lazy.activate(context);
        const tool = lazy.tools.get(PLAN_TOOL);
        if (!tool) throw new Error("Plannotator did not register plannotator_submit_plan");
        return tool.execute(toolCallId, params, signal, onUpdate, context);
      },
    });

    api.on("session_start", async (event: unknown, context: unknown) => {
      if (!lazy.isActivated() && Reflect.get(api, "getFlag")?.call(api, "plan") === true) {
        await lazy.activate(context);
        return;
      }
      if (lazy.isActivated()) return lazy.emit("session_start", event, context);
    });
  };
}

export default createLazyPlannotator();
