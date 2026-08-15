type Handler = (...args: unknown[]) => unknown;

type Command = {
  handler: Handler;
};

type Shortcut = {
  handler: Handler;
};

type Tool = {
  name: string;
  execute: Handler;
  renderCall?: Handler;
  renderResult?: Handler;
};

type LazyExtensionApi = {
  on(event: string, handler: Handler): void;
  registerCommand(name: string, command: Command): void;
  registerFlag(name: string, flag: unknown): void;
  registerShortcut(shortcut: string, options: Shortcut): void;
  registerTool(tool: Tool): void;
};

type ExtensionModule = {
  default?: (api: LazyExtensionApi) => unknown;
};

function bindApiMember(api: LazyExtensionApi, property: PropertyKey, receiver: unknown) {
  const value = Reflect.get(api, property, receiver);
  return typeof value === "function" ? value.bind(api) : value;
}

function appendHandler(handlers: Map<string, Handler[]>, event: string, handler: Handler) {
  const eventHandlers = handlers.get(event) ?? [];
  eventHandlers.push(handler);
  handlers.set(event, eventHandlers);
}

export function createLazyActivation({
  api,
  captureCommands = [],
  captureEvents = [],
  captureFlags = [],
  captureShortcuts = [],
  captureTools = [],
  importExtension,
  replayEvents = [],
}: {
  api: LazyExtensionApi;
  captureCommands?: string[];
  captureEvents?: string[];
  captureFlags?: string[];
  captureShortcuts?: string[];
  captureTools?: string[];
  importExtension: () => Promise<ExtensionModule>;
  replayEvents?: string[];
}) {
  const capturedCommands = new Map<string, Command>();
  const capturedEvents = new Map<string, Handler[]>();
  const capturedFlags = new Map<string, unknown>();
  const capturedShortcuts = new Map<string, Shortcut>();
  const capturedTools = new Map<string, Tool>();
  const commandNames = new Set(captureCommands);
  const eventNames = new Set(captureEvents);
  const flagNames = new Set(captureFlags);
  const replayEventNames = new Set(replayEvents);
  const shortcutNames = new Set(captureShortcuts);
  const toolNames = new Set(captureTools);
  let activation: Promise<void> | undefined;
  let activated = false;

  const proxy = new Proxy(api, {
    get(target, property, receiver) {
      if (property === "on") {
        return (event: string, handler: Handler) => {
          if (eventNames.has(event) || replayEventNames.has(event)) {
            appendHandler(capturedEvents, event, handler);
          }
          if (!eventNames.has(event) && !replayEventNames.has(event)) {
            target.on(event, handler);
          }
        };
      }
      if (property === "registerCommand") {
        return (name: string, command: Command) => {
          if (commandNames.has(name)) {
            capturedCommands.set(name, command);
            return;
          }
          target.registerCommand(name, command);
        };
      }
      if (property === "registerFlag") {
        return (name: string, flag: unknown) => {
          if (flagNames.has(name)) {
            capturedFlags.set(name, flag);
            return;
          }
          target.registerFlag(name, flag);
        };
      }
      if (property === "registerShortcut") {
        return (shortcut: string, options: Shortcut) => {
          if (shortcutNames.has(shortcut)) {
            capturedShortcuts.set(shortcut, options);
            return;
          }
          target.registerShortcut(shortcut, options);
        };
      }
      if (property === "registerTool") {
        return (tool: Tool) => {
          if (toolNames.has(tool.name)) {
            capturedTools.set(tool.name, tool);
            return;
          }
          target.registerTool(tool);
        };
      }
      return bindApiMember(target, property, receiver);
    },
  });

  async function emit(event: string, payload: unknown, context: unknown) {
    let result: unknown;
    for (const handler of capturedEvents.get(event) ?? []) {
      const next = await handler(payload, context);
      if (next !== undefined) result = next;
    }
    return result;
  }

  async function activate(context: unknown) {
    activation ??= (async () => {
      const module = await importExtension();
      if (typeof module.default !== "function") {
        throw new TypeError("Lazy extension module must export a default factory");
      }
      await module.default(proxy);
      for (const event of replayEventNames) {
        await emit(event, { type: event, reason: "reload" }, context);
      }
      activated = true;
    })();
    await activation;
  }

  return {
    activate,
    commands: capturedCommands,
    emit,
    flags: capturedFlags,
    isActivated: () => activated,
    shortcuts: capturedShortcuts,
    tools: capturedTools,
  };
}
