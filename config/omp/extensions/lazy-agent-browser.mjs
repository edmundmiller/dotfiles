import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

import { createLazyActivation } from "./_lib/lazy-extension.mjs";

const CAPTURED_EVENTS = [
  "session_start",
  "session_tree",
  "session_shutdown",
  "before_agent_start",
  "tool_call",
  "tool_result",
];

function browserPackageRoot() {
  const configDirectory = process.env.PI_CONFIG_DIR || ".omp";
  return join(homedir(), configDirectory, "plugins", "node_modules", "pi-agent-browser-native");
}

function importFromBrowserPackage(relativePath) {
  return import(pathToFileURL(join(browserPackageRoot(), relativePath)).href);
}

async function importAgentBrowser() {
  return importFromBrowserPackage("dist/extensions/agent-browser/index.js");
}

async function loadBrowserSurface() {
  const [config, inputModes, playbook, promptPolicy, tui] = await Promise.all([
    importFromBrowserPackage("dist/extensions/agent-browser/lib/config.js"),
    importFromBrowserPackage("dist/extensions/agent-browser/lib/input-modes.js"),
    importFromBrowserPackage("dist/extensions/agent-browser/lib/playbook.js"),
    importFromBrowserPackage("dist/extensions/agent-browser/lib/prompt-policy.js"),
    import("@earendil-works/pi-tui"),
  ]);
  const browserConfig = config.loadAgentBrowserConfigSync({
    cwd: process.cwd(),
    includeProjectConfig: false,
  });
  globalThis.__dotfilesOmpLazyPluginHost = {
    ...globalThis.__dotfilesOmpLazyPluginHost,
    Text: tui.Text,
    getKeybindings: tui.getKeybindings,
    truncateToWidth: tui.truncateToWidth,
  };
  const root = browserPackageRoot();

  return {
    parameters: inputModes.AGENT_BROWSER_PARAMS,
    promptGuidelines: playbook.buildToolPromptGuidelines({
      browserDefaultProfile: browserConfig.trustedBrowserDefaultProfile,
      browserExecutablePath: browserConfig.trustedBrowserExecutablePath,
      includeWebSearch: config.canRegisterWebSearchTool(browserConfig),
      docs: {
        readmePath: join(root, "README.md"),
        commandReferencePath: join(root, "docs", "COMMAND_REFERENCE.md"),
        toolContractPath: join(root, "docs", "TOOL_CONTRACT.md"),
      },
    }),
    shouldActivateForPrompt: promptPolicy.shouldAppendBrowserSystemPrompt,
    renderFallback(args, _theme, context) {
      const text =
        context.lastComponent instanceof tui.Text ? context.lastComponent : new tui.Text("", 0, 0);
      const command = Array.isArray(args?.args) ? args.args.join(" ") : "";
      text.setText(command ? `agent_browser ${command}` : "agent_browser");
      return text;
    },
  };
}

function shouldActivateForToolCall(event) {
  return event?.toolName === "agent_browser" || event?.toolName === "bash";
}

export function createLazyAgentBrowser({
  importExtension = importAgentBrowser,
  loadSurface = loadBrowserSurface,
} = {}) {
  return async function lazyAgentBrowser(api) {
    const surface = await loadSurface();
    const lazy = createLazyActivation({
      api,
      captureEvents: CAPTURED_EVENTS,
      captureTools: ["agent_browser"],
      importExtension,
      replayEvents: ["session_start"],
    });

    api.on("session_start", async (event, context) => {
      if (lazy.isActivated()) return lazy.emit("session_start", event, context);
    });
    api.on("session_tree", async (event, context) => {
      if (lazy.isActivated()) return lazy.emit("session_tree", event, context);
    });
    api.on("session_shutdown", async (event, context) => {
      if (lazy.isActivated()) return lazy.emit("session_shutdown", event, context);
    });
    api.on("before_agent_start", async (event, context) => {
      if (!lazy.isActivated() && !surface.shouldActivateForPrompt(event.prompt)) {
        return undefined;
      }
      await lazy.activate(context);
      return lazy.emit("before_agent_start", event, context);
    });
    api.on("tool_call", async (event, context) => {
      if (!lazy.isActivated() && !shouldActivateForToolCall(event)) {
        return undefined;
      }
      await lazy.activate(context);
      return lazy.emit("tool_call", event, context);
    });
    api.on("tool_result", async (event, context) => {
      if (lazy.isActivated()) return lazy.emit("tool_result", event, context);
    });

    api.registerTool({
      name: "agent_browser",
      label: "Agent Browser",
      description:
        "Browse and interact with websites using agent-browser. Use this for web research, reading live docs, opening pages, taking snapshots or screenshots, clicking links, filling forms, extracting page content, and authenticated/profile-based browser work. Input choice: default `args` for open → snapshot -i → click/fill @refs; `semanticAction` for stable role/text/label targets; `job` or `qa` for multi-step checks; `electron` only for desktop apps; experimental `sourceLookup` / `networkSourceLookup` for candidates only.",
      promptSnippet:
        "Browse websites, read live docs, click and fill pages, extract browser content, take screenshots, and automate real web workflows.",
      promptGuidelines: surface.promptGuidelines,
      parameters: surface.parameters,
      renderCall(...args) {
        const tool = lazy.tools.get("agent_browser");
        return tool?.renderCall ? tool.renderCall(...args) : surface.renderFallback?.(...args);
      },
      renderResult(...args) {
        const tool = lazy.tools.get("agent_browser");
        return tool?.renderResult
          ? tool.renderResult(...args)
          : surface.renderFallback?.({}, ...args);
      },
      async execute(toolCallId, params, signal, onUpdate, context) {
        await lazy.activate(context);
        const tool = lazy.tools.get("agent_browser");
        if (!tool) {
          throw new Error("pi-agent-browser-native did not register agent_browser");
        }
        return tool.execute(toolCallId, params, signal, onUpdate, context);
      },
    });
  };
}

export default createLazyAgentBrowser();
