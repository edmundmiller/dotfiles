/* oxlint-disable anti-slop/no-known-value-widening, anti-slop/no-unknown-parameters, anti-slop/no-runtime-typeof, anti-slop/require-safety-comment-for-type-assertion */
/**
 * Harness tests for the pi-beads extension wiring.
 *
 * The real TUI pages (pi-tui) and the native clipboard module are mocked at the
 * module boundary so tests exercise extension logic deterministically:
 * mocked showTaskForm invokes onSave, mocked showTaskList exposes
 * cycle/hotkey/create callbacks, and readClipboard feeds clipboard refs.
 */

import { describe, test, expect, mock } from "bun:test";
import type { Task } from "./models/task.ts";
import type { TaskAdapter, TaskUpdate } from "./backend/api.ts";
import type { ListPageConfig } from "./ui/pages/list.ts";
import type { ShowTaskFormOptions } from "./ui/pages/show.ts";
import type { FormDraft } from "./controllers/show.ts";

let clipboardText = "";

mock.module("@mariozechner/clipboard", () => ({
  getText: async () => clipboardText,
}));

// The real pages pull pi-tui at import time; stub them so extension.ts loads
// without a terminal. Extension deps override these defaults anyway.
mock.module("./ui/pages/list.ts", () => ({
  showTaskList: async () => {},
}));
mock.module("./ui/pages/show.ts", () => ({
  showTaskForm: async () => ({ action: "back" }),
}));

import registerExtension, { findClipboardBeadRef } from "./extension.ts";

// ---- Fakes ----

type CommandHandler = (rawArgs: string, ctx: any) => Promise<void>;

function makePi() {
  const commands = new Map<string, { description: string; handler: CommandHandler }>();
  const shortcuts = new Map<string, { description: string; handler: CommandHandler }>();
  const sentMessages: string[] = [];
  return {
    registerCommand: (name: string, def: { description: string; handler: CommandHandler }) => {
      commands.set(name, def);
    },
    registerShortcut: (key: string, def: { description: string; handler: CommandHandler }) => {
      shortcuts.set(key, def);
    },
    sendUserMessage: (msg: string) => {
      sentMessages.push(msg);
    },
    _commands: commands,
    _shortcuts: shortcuts,
    _sentMessages: sentMessages,
  };
}

function makeCtx() {
  const notifications: { message: string; level: string }[] = [];
  const pastes: string[] = [];
  const ui = {
    setStatus: () => {},
    notify: (message: string, level: string) => {
      notifications.push({ message, level });
    },
    pasteToEditor: (text: string) => {
      pastes.push(text);
    },
  };
  return { hasUI: true, ui, _notifications: notifications, _pastes: pastes };
}

const VALID_BACKEND: TaskAdapter = {
  id: "beads",
  statusMap: {
    open: "open",
    inProgress: "in_progress",
    blocked: "blocked",
    deferred: "deferred",
    closed: "closed",
  },
  taskTypes: ["task", "feature", "bug", "chore", "epic"],
  priorities: ["p0", "p1", "p2", "p3", "p4"],
  priorityHotkeys: { "0": "p0", "1": "p1", "2": "p2", "3": "p3", "4": "p4" },
  list: async () => [],
  show: async (ref) => {
    throw new Error(`Task not found: ${ref}`);
  },
  update: async () => {},
  create: async (input) => ({
    ref: "beads-new",
    id: "beads-new",
    title: input.title,
    description: input.description ?? "",
    status: input.status ?? "open",
    priority: input.priority,
  }),
};

function makeBackend(overrides: Partial<TaskAdapter> = {}) {
  const updateCalls: { ref: string; update: TaskUpdate }[] = [];
  const createCalls: { input: Parameters<TaskAdapter["create"]>[0] }[] = [];
  const backend: TaskAdapter = {
    ...VALID_BACKEND,
    update: async (ref, update) => {
      updateCalls.push({ ref, update });
    },
    create: async (input) => {
      createCalls.push({ input });
      return VALID_BACKEND.create!(input);
    },
    ...overrides,
  };
  return { backend, updateCalls, createCalls };
}

/** Register the extension and capture the beads-tasks command handler. */
function registerAndGetCommand(
  pi: ReturnType<typeof makePi>,
  backend: TaskAdapter,
  deps: {
    readClipboard?: () => Promise<string>;
    showTaskList?: typeof import("./ui/pages/list.ts").showTaskList;
    showTaskForm?: typeof import("./ui/pages/show.ts").showTaskForm;
  } = {}
) {
  registerExtension(pi as any, {
    backend,
    readClipboard: deps.readClipboard ?? (async () => ""),
    showTaskList: deps.showTaskList,
    showTaskForm: deps.showTaskForm,
  });
  const command = pi._commands.get("beads-tasks");
  if (!command) throw new Error("beads-tasks command not registered");
  return command;
}

function makeListPageMock() {
  const configs: ListPageConfig[] = [];
  const page = async (_ctx: unknown, config: ListPageConfig) => {
    configs.push(config);
  };
  return { page, configs };
}

function makeFormPageMock() {
  const optionsList: ShowTaskFormOptions[] = [];
  const page = async (_ctx: unknown, options: ShowTaskFormOptions) => {
    optionsList.push(options);
    return { action: "back" as const };
  };
  return { page, optionsList };
}

const baseTask: Task = {
  ref: "beads-1",
  id: "beads-1",
  title: "Test task",
  description: "",
  status: "open",
  priority: "p2",
  taskType: "task",
};

// ---- findClipboardBeadRef ----

describe("findClipboardBeadRef", () => {
  test("finds an exact bead ref among clipboard text", () => {
    expect(findClipboardBeadRef("see dotfiles-42zj for details", ["dotfiles-42zj"])).toBe(
      "dotfiles-42zj"
    );
  });

  test("ignores tokens that are not known refs", () => {
    expect(findClipboardBeadRef("pi-beads should look for a bead", ["beads-1"])).toBeNull();
  });

  test("handles dotted refs", () => {
    expect(findClipboardBeadRef("workspace-rtl.1", ["workspace-rtl.1", "beads-1"])).toBe(
      "workspace-rtl.1"
    );
  });
});

// ---- Clipboard preselection (bead 42zj) ----

describe("clipboard bead preselection", () => {
  test("opens the list with initialSelectedRef when clipboard holds a known ref", async () => {
    const pi = makePi();
    const ctx = makeCtx();
    const { backend } = makeBackend({
      list: async () => [
        { ...baseTask, ref: "beads-1" },
        { ...baseTask, ref: "dotfiles-42zj", title: "Clipboard bead" },
      ],
    });
    const listPage = makeListPageMock();

    const command = registerAndGetCommand(pi, backend, {
      readClipboard: async () => "copy dotfiles-42zj",
      showTaskList: listPage.page as any,
    });

    await command.handler("", ctx as any);

    expect(listPage.configs.length).toBe(1);
    expect(listPage.configs[0].initialSelectedRef).toBe("dotfiles-42zj");
  });

  test("opens without preselection when clipboard has no known ref", async () => {
    const pi = makePi();
    const ctx = makeCtx();
    const { backend } = makeBackend({
      list: async () => [{ ...baseTask, ref: "beads-1" }],
    });
    const listPage = makeListPageMock();

    const command = registerAndGetCommand(pi, backend, {
      readClipboard: async () => "no bead here",
      showTaskList: listPage.page as any,
    });

    await command.handler("", ctx as any);

    expect(listPage.configs.length).toBe(1);
    expect(listPage.configs[0].initialSelectedRef).toBeUndefined();
  });

  test("survives clipboard read failure and still opens the list", async () => {
    const pi = makePi();
    const ctx = makeCtx();
    const { backend } = makeBackend({
      list: async () => [{ ...baseTask, ref: "beads-1" }],
    });
    const listPage = makeListPageMock();

    const command = registerAndGetCommand(pi, backend, {
      readClipboard: async () => {
        throw new Error("clipboard unavailable");
      },
      showTaskList: listPage.page as any,
    });

    await command.handler("", ctx as any);

    expect(listPage.configs.length).toBe(1);
    expect(listPage.configs[0].initialSelectedRef).toBeUndefined();
  });
});

// ---- Task creation (bead hdky) ----

describe("task creation wiring", () => {
  test("createTask routes form save to backend.create with draft fields", async () => {
    const pi = makePi();
    const ctx = makeCtx();
    const { backend, createCalls } = makeBackend();
    const listPage = makeListPageMock();
    const formPage = makeFormPageMock();

    const command = registerAndGetCommand(pi, backend, {
      showTaskList: listPage.page as any,
      showTaskForm: formPage.page as any,
    });

    await command.handler("", ctx as any);
    const listConfig = listPage.configs[0];

    // Open create form from the list.
    const createdTask = listConfig.onCreate!();
    await createdTask;

    const formOptions = formPage.optionsList[0];
    expect(formOptions.mode).toBe("create");

    // Mocked form invokes onSave with the user draft.
    const draft: FormDraft = {
      title: "New task",
      description: "Some details",
      status: "open",
      priority: "p1",
      taskType: "bug",
    };
    const saved = await formOptions.onSave(draft);

    expect(saved).toBe(true);
    expect(createCalls.length).toBe(1);
    expect(createCalls[0].input).toEqual({
      title: "New task",
      description: "Some details",
      status: "open",
      priority: "p1",
      taskType: "bug",
    });
  });

  test("createTask rejects empty titles", async () => {
    const pi = makePi();
    const ctx = makeCtx();
    const { backend, createCalls } = makeBackend();
    const listPage = makeListPageMock();
    const formPage = makeFormPageMock();

    const command = registerAndGetCommand(pi, backend, {
      showTaskList: listPage.page as any,
      showTaskForm: formPage.page as any,
    });

    await command.handler("", ctx as any);
    const listConfig = listPage.configs[0];
    await listConfig.onCreate!();

    const formOptions = formPage.optionsList[0];
    const error = await formOptions
      .onSave({ title: "   ", description: "", status: "open", priority: "p2", taskType: "task" })
      .catch((e) => e);

    expect(error).toBeInstanceOf(Error);
    expect((error as Error).message).toContain("Title is required");
    expect(createCalls.length).toBe(0);
  });

  test("create with non-open status forwards the status to backend.create", async () => {
    const pi = makePi();
    const ctx = makeCtx();
    const { backend, createCalls } = makeBackend();
    const listPage = makeListPageMock();
    const formPage = makeFormPageMock();

    const command = registerAndGetCommand(pi, backend, {
      showTaskList: listPage.page as any,
      showTaskForm: formPage.page as any,
    });

    await command.handler("", ctx as any);
    await listPage.configs[0].onCreate!();
    await formPage.optionsList[0].onSave({
      title: "In-flight",
      description: "",
      status: "inProgress",
      priority: "p2",
      taskType: "task",
    });

    expect(createCalls.length).toBe(1);
    // The follow-up update for non-open status is adapter-level behavior
    // (covered in beads.test.ts); here verify the extension forwards the
    // requested status to create.
    expect(createCalls[0].input.status).toBe("inProgress");
  });
});

// ---- Status cycling (bead hdky) ----

describe("status cycling wiring", () => {
  test("cycleStatus follows statusMap order and wraps", async () => {
    const pi = makePi();
    const ctx = makeCtx();
    const { backend } = makeBackend();
    const listPage = makeListPageMock();

    const command = registerAndGetCommand(pi, backend, {
      showTaskList: listPage.page as any,
    });

    await command.handler("", ctx as any);
    const cycleStatus = listPage.configs[0].cycleStatus;

    expect(cycleStatus("open")).toBe("inProgress");
    expect(cycleStatus("inProgress")).toBe("blocked");
    expect(cycleStatus("blocked")).toBe("deferred");
    expect(cycleStatus("deferred")).toBe("closed");
    // Wraps back to the first status in the map.
    expect(cycleStatus("closed")).toBe("open");
  });

  test("toggleStatus routes the cycled status to backend.update", async () => {
    const pi = makePi();
    const ctx = makeCtx();
    const { backend, updateCalls } = makeBackend({
      list: async () => [{ ...baseTask, status: "open" as const }],
    });
    const listPage = makeListPageMock();

    const command = registerAndGetCommand(pi, backend, {
      showTaskList: listPage.page as any,
    });

    await command.handler("", ctx as any);
    const config = listPage.configs[0];
    const next = config.cycleStatus("open");
    await config.onUpdateTask("beads-1", { status: next });

    expect(updateCalls).toEqual([{ ref: "beads-1", update: { status: "inProgress" } }]);
  });
});

// ---- Priority hotkeys (bead hdky) ----

describe("priority hotkey wiring", () => {
  test("exposes backend priorityHotkeys to the list page", async () => {
    const pi = makePi();
    const ctx = makeCtx();
    const { backend } = makeBackend();
    const listPage = makeListPageMock();

    const command = registerAndGetCommand(pi, backend, {
      showTaskList: listPage.page as any,
    });

    await command.handler("", ctx as any);

    expect(listPage.configs[0].priorityHotkeys).toEqual({
      "0": "p0",
      "1": "p1",
      "2": "p2",
      "3": "p3",
      "4": "p4",
    });
    expect(listPage.configs[0].priorities).toEqual(["p0", "p1", "p2", "p3", "p4"]);
  });

  test("setPriority routes the hotkey priority to backend.update", async () => {
    const pi = makePi();
    const ctx = makeCtx();
    const { backend, updateCalls } = makeBackend({
      list: async () => [{ ...baseTask, priority: "p2" }],
    });
    const listPage = makeListPageMock();

    const command = registerAndGetCommand(pi, backend, {
      showTaskList: listPage.page as any,
    });

    await command.handler("", ctx as any);
    await listPage.configs[0].onUpdateTask("beads-1", { priority: "p0" });

    expect(updateCalls).toEqual([{ ref: "beads-1", update: { priority: "p0" } }]);
  });
});

// ---- Backend validation (bead hdky) ----

describe("backend validation", () => {
  test("throws when statusMap lacks open/closed", () => {
    const pi = makePi();
    const backend = {
      ...VALID_BACKEND,
      statusMap: { open: "open" },
    };

    expect(() => registerExtension(pi as any, { backend } as any)).toThrow(
      /statusMap must include open and closed/
    );
  });

  test("throws when taskTypes are empty", () => {
    const pi = makePi();
    const backend: TaskAdapter = { ...VALID_BACKEND, taskTypes: [] };

    expect(() => registerExtension(pi as any, { backend } as any)).toThrow(
      /taskTypes must not be empty/
    );
  });

  test("throws when priorities fall outside 3-5 range", () => {
    const pi = makePi();
    const backend: TaskAdapter = { ...VALID_BACKEND, priorities: ["p0", "p1"] };

    expect(() => registerExtension(pi as any, { backend } as any)).toThrow(
      /priorities must contain 3 to 5 values/
    );
  });

  test("throws when a priority hotkey points at an unsupported priority", () => {
    const pi = makePi();
    const backend: TaskAdapter = {
      ...VALID_BACKEND,
      priorityHotkeys: { "0": "p9" },
    };

    expect(() => registerExtension(pi as any, { backend } as any)).toThrow(
      /hotkey .* points to unsupported priority/
    );
  });

  test("accepts a valid backend and registers command + shortcut", () => {
    const pi = makePi();
    const { backend } = makeBackend();

    registerExtension(pi as any, { backend });

    expect(pi._commands.has("beads-tasks")).toBe(true);
    expect(pi._shortcuts.has("ctrl+x")).toBe(true);

    const command = pi._commands.get("beads-tasks")!;
    // Shortcut path (no UI) is a no-op.
    command.handler("", { hasUI: false } as any);
  });
});
