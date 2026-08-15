import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

import { createLazyActivation } from "./lib/lazy-extension";

const CAPTURED_EVENTS = [
  "session_start",
  "session_tree",
  "session_shutdown",
  "before_agent_start",
  "tool_call",
  "tool_result",
];

function browserPackageRoot() {
  const agentRoot = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
  return join(agentRoot, "npm", "node_modules", "pi-agent-browser-native");
}

function importFromBrowserPackage(relativePath: string) {
  return import(pathToFileURL(join(browserPackageRoot(), relativePath)).href);
}

async function importAgentBrowser() {
  return importFromBrowserPackage("dist/extensions/agent-browser/index.js");
}

async function loadBrowserSurface() {
  const [config, inputModes, playbook, promptPolicy, tui] = await Promise.all([
    importFromBrowserPackage("dist/extensions/agent-browser/lib/config.js"),
    importFromBrowserPackage("dist/extensions/agent-browser/lib/input-modes/params.js"),
    importFromBrowserPackage("dist/extensions/agent-browser/lib/playbook.js"),
    importFromBrowserPackage("dist/extensions/agent-browser/lib/prompt-policy.js"),
    import(
      pathToFileURL(
        join(piAgentRoot(), "npm", "node_modules", "@earendil-works", "pi-tui", "dist", "index.js")
      ).href
    ),
  ]);
  const browserConfig = config.loadAgentBrowserConfigSync({
    cwd: process.cwd(),
    includeProjectConfig: false,
  });
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
    renderFallback(args: unknown, _theme: unknown, context: unknown) {
      const current = Reflect.get(Object(context), "lastComponent");
      const text = current instanceof tui.Text ? current : new tui.Text("", 0, 0);
      const input = Reflect.get(Object(args), "args");
      const command = Array.isArray(input) ? input.join(" ") : "";
      text.setText(command ? `agent_browser ${command}` : "agent_browser");
      return text;
    },
  };
}

function piAgentRoot() {
  return process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
}

function shouldActivateForToolCall(event: unknown) {
  const toolName = Reflect.get(Object(event), "toolName");
  return toolName === "agent_browser" || toolName === "bash";
}

type BrowserSurface = Awaited<ReturnType<typeof loadBrowserSurface>>;

export function createLazyAgentBrowser({
  importExtension = importAgentBrowser,
  loadSurface = loadBrowserSurface,
}: {
  importExtension?: () => Promise<{
    default?: (api: Parameters<typeof createLazyActivation>[0]["api"]) => unknown;
  }>;
  loadSurface?: () => Promise<BrowserSurface>;
} = {}) {
  return async function lazyAgentBrowser(api: Parameters<typeof createLazyActivation>[0]["api"]) {
    const surface = await loadSurface();
    const lazy = createLazyActivation({
      api,
      captureEvents: CAPTURED_EVENTS,
      captureTools: ["agent_browser"],
      importExtension,
      replayEvents: ["session_start"],
    });

    api.on("session_start", async (event: unknown, context: unknown) => {
      if (lazy.isActivated()) return lazy.emit("session_start", event, context);
    });
    api.on("session_tree", async (event: unknown, context: unknown) => {
      if (lazy.isActivated()) return lazy.emit("session_tree", event, context);
    });
    api.on("session_shutdown", async (event: unknown, context: unknown) => {
      if (lazy.isActivated()) return lazy.emit("session_shutdown", event, context);
    });
    api.on("before_agent_start", async (event: unknown, context: unknown) => {
      const prompt = Reflect.get(Object(event), "prompt");
      if (!lazy.isActivated() && !surface.shouldActivateForPrompt(String(prompt ?? ""))) {
        return undefined;
      }
      await lazy.activate(context);
      return lazy.emit("before_agent_start", event, context);
    });
    api.on("tool_call", async (event: unknown, context: unknown) => {
      if (!lazy.isActivated() && !shouldActivateForToolCall(event)) return undefined;
      await lazy.activate(context);
      return lazy.emit("tool_call", event, context);
    });
    api.on("tool_result", async (event: unknown, context: unknown) => {
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
      renderCall(...args: unknown[]) {
        const tool = lazy.tools.get("agent_browser");
        return tool?.renderCall ? tool.renderCall(...args) : surface.renderFallback(...args);
      },
      renderResult(...args: unknown[]) {
        const tool = lazy.tools.get("agent_browser");
        return tool?.renderResult
          ? tool.renderResult(...args)
          : surface.renderFallback({}, ...args);
      },
      async execute(
        toolCallId: unknown,
        params: unknown,
        signal: unknown,
        onUpdate: unknown,
        context: unknown
      ) {
        await lazy.activate(context);
        const tool = lazy.tools.get("agent_browser");
        if (!tool) throw new Error("pi-agent-browser-native did not register agent_browser");
        return tool.execute(toolCallId, params, signal, onUpdate, context);
      },
    });
  };
}

export default createLazyAgentBrowser();
