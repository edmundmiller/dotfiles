function bindApiMember(api, property, receiver) {
  const value = Reflect.get(api, property, receiver);
  return typeof value === "function" ? value.bind(api) : value;
}

function appendHandler(handlers, event, handler) {
  const eventHandlers = handlers.get(event) ?? [];
  eventHandlers.push(handler);
  handlers.set(event, eventHandlers);
}

export function createLazyActivation({
  api,
  captureCommands = [],
  captureEvents = [],
  captureTools = [],
  importExtension,
  replayEvents = [],
}) {
  const capturedCommands = new Map();
  const capturedEvents = new Map();
  const capturedTools = new Map();
  const commandNames = new Set(captureCommands);
  const eventNames = new Set(captureEvents);
  const replayEventNames = new Set(replayEvents);
  const toolNames = new Set(captureTools);
  let activation;
  let activated = false;

  const proxy = new Proxy(api, {
    get(target, property, receiver) {
      if (property === "on") {
        return (event, handler) => {
          if (eventNames.has(event) || replayEventNames.has(event)) {
            appendHandler(capturedEvents, event, handler);
          }
          if (!eventNames.has(event)) {
            target.on(event, handler);
          }
        };
      }
      if (property === "registerCommand") {
        return (name, options) => {
          if (commandNames.has(name)) {
            capturedCommands.set(name, options);
            return;
          }
          target.registerCommand(name, options);
        };
      }
      if (property === "registerTool") {
        return (tool) => {
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

  async function emit(event, payload, context) {
    let result;
    for (const handler of capturedEvents.get(event) ?? []) {
      const next = await handler(payload, context);
      if (next !== undefined) result = next;
    }
    return result;
  }

  async function activate(context) {
    activation ??= (async () => {
      const module = await importExtension();
      if (typeof module?.default !== "function") {
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
    isActivated: () => activated,
    tools: capturedTools,
  };
}
