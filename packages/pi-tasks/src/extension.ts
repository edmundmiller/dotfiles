import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent"
import initializeAdapter from "./backend/resolver.ts"
import type { Task, TaskStatus } from "./models/task.ts"
import { buildTaskWorkPrompt, serializeTask } from "./lib/task-serialization.ts"
import { showTaskList } from "./ui/pages/list.ts"
import { showTaskForm } from "./ui/pages/show.ts"
import type { TaskUpdate } from "./backend/api.ts"

const CTRL_X = "\x18"

function parsePriorityKey(
  data: string,
  priorities: string[],
  priorityHotkeys?: Record<string, string>,
): string | null {
  if (data.length !== 1) return null

  const hotkeyPriority = priorityHotkeys?.[data]
  if (hotkeyPriority && priorities.includes(hotkeyPriority)) return hotkeyPriority

  const rank = parseInt(data, 10)
  if (isNaN(rank) || rank < 1 || rank > priorities.length) return null
  return priorities[rank - 1] ?? null
}

function cycleStatus(current: TaskStatus, statusMap: Record<string, string>): TaskStatus {
  const statusCycle = Object.keys(statusMap) as TaskStatus[]
  if (statusCycle.length === 0) return "open"
  const idx = statusCycle.indexOf(current)
  if (idx === -1) return statusCycle[0]
  return statusCycle[(idx + 1) % statusCycle.length]
}

function cycleTaskType(current: string | undefined, taskTypes: string[]): string {
  if (taskTypes.length === 0) return "task"
  const normalized = current || taskTypes[0]
  const idx = taskTypes.indexOf(normalized)
  if (idx === -1) return taskTypes[0]
  return taskTypes[(idx + 1) % taskTypes.length]
}

function defaultPriority(priorities: string[]): string | undefined {
  if (priorities.length === 0) return undefined
  return priorities[Math.floor(priorities.length / 2)]
}

function defaultTaskType(taskTypes: string[]): string | undefined {
  return taskTypes[0]
}

function hasUniqueValues(values: string[]): boolean {
  return new Set(values).size === values.length
}

function validateBackendConfiguration(backend: {
  id: string
  statusMap: Record<string, string>
  taskTypes: string[]
  priorities: string[]
  priorityHotkeys?: Record<string, string>
}): void {
  const statusKeys = Object.keys(backend.statusMap)
  if (statusKeys.length === 0) {
    throw new Error(`Invalid backend config (${backend.id}): statusMap must not be empty`)
  }

  if (!statusKeys.includes("open") || !statusKeys.includes("closed")) {
    throw new Error(`Invalid backend config (${backend.id}): statusMap must include open and closed`)
  }

  if (backend.taskTypes.length === 0) {
    throw new Error(`Invalid backend config (${backend.id}): taskTypes must not be empty`)
  }

  if (!hasUniqueValues(backend.taskTypes)) {
    throw new Error(`Invalid backend config (${backend.id}): taskTypes must be unique`)
  }

  if (backend.priorities.length < 3 || backend.priorities.length > 5) {
    throw new Error(`Invalid backend config (${backend.id}): priorities must contain 3 to 5 values`)
  }

  if (!hasUniqueValues(backend.priorities)) {
    throw new Error(`Invalid backend config (${backend.id}): priorities must be unique`)
  }

  if (backend.priorityHotkeys) {
    for (const [key, priority] of Object.entries(backend.priorityHotkeys)) {
      if (key.length !== 1) {
        throw new Error(`Invalid backend config (${backend.id}): priority hotkey keys must be a single character`)
      }

      if (!backend.priorities.includes(priority)) {
        throw new Error(`Invalid backend config (${backend.id}): priority hotkey ${key} points to unsupported priority ${priority}`)
      }
    }
  }
}

interface EditTaskResult {
  updatedTask: Task | null
  closeList: boolean
}

function buildTaskUpdate(previous: Task, next: {
  title: string
  description: string
  status: TaskStatus
  priority: string | undefined
  taskType: string | undefined
}): TaskUpdate {
  const update: TaskUpdate = {}

  const nextTitle = next.title.trim()
  if (nextTitle !== previous.title.trim()) {
    update.title = nextTitle
  }

  if (next.description !== (previous.description ?? "")) {
    update.description = next.description
  }

  if (next.status !== previous.status) {
    update.status = next.status
  }

  if (next.priority !== previous.priority && next.priority !== undefined) {
    update.priority = next.priority
  }

  if (next.taskType !== previous.taskType) {
    update.taskType = next.taskType || "task"
  }

  return update
}

function hasTaskUpdate(update: TaskUpdate): boolean {
  return Object.keys(update).length > 0
}

function applyDraftToTask(
  task: Task,
  draft: {
    title: string
    description: string
    status: TaskStatus
    priority: string | undefined
    taskType: string | undefined
  },
): Task {
  const nextTask: Task = {
    ...task,
    title: draft.title.trim(),
    description: draft.description,
    status: draft.status,
  }

  if (draft.priority !== undefined) {
    nextTask.priority = draft.priority
  } else {
    delete nextTask.priority
  }

  if (draft.taskType !== undefined) {
    nextTask.taskType = draft.taskType
  } else {
    delete nextTask.taskType
  }

  return nextTask
}

export default function registerExtension(pi: ExtensionAPI) {
  const backend = initializeAdapter(pi)
  validateBackendConfiguration(backend)

  const nextStatus = (status: TaskStatus): TaskStatus => cycleStatus(status, backend.statusMap)
  const nextTaskType = (current: string | undefined): string => cycleTaskType(current, backend.taskTypes)
  const nextPriorityFromKey = (data: string): string | null => parsePriorityKey(
    data,
    backend.priorities,
    backend.priorityHotkeys,
  )

  async function listTasks(): Promise<Task[]> {
    return backend.list()
  }

  async function showTask(ref: string): Promise<Task> {
    return backend.show(ref)
  }

  function needsTaskDetailsForEdit(task: Task): boolean {
    return task.description === undefined
  }

  async function getTaskForEdit(ref: string, fromList?: Task): Promise<Task> {
    if (!fromList) return showTask(ref)
    if (needsTaskDetailsForEdit(fromList)) return showTask(ref)
    return { ...fromList }
  }

  async function updateTask(ref: string, update: TaskUpdate): Promise<void> {
    await backend.update(ref, update)
  }

  async function editTask(ctx: ExtensionCommandContext, ref: string, fromList?: Task): Promise<EditTaskResult> {
    let task = await getTaskForEdit(ref, fromList)

    const formResult = await showTaskForm(ctx, {
      mode: "edit",
      subtitle: "Edit",
      task,
      closeKey: CTRL_X,
      cycleStatus: nextStatus,
      cycleTaskType: nextTaskType,
      parsePriorityKey: nextPriorityFromKey,
      priorities: backend.priorities,
      priorityHotkeys: backend.priorityHotkeys,
      onSave: async (draft) => {
        const update = buildTaskUpdate(task, {
          title: draft.title,
          description: draft.description,
          status: draft.status,
          priority: draft.priority,
          taskType: draft.taskType,
        })

        if (!hasTaskUpdate(update)) return false

        await updateTask(ref, update)
        task = applyDraftToTask(task, {
          title: draft.title,
          description: draft.description,
          status: draft.status,
          priority: draft.priority,
          taskType: draft.taskType,
        })
        return true
      },
    })

    return {
      updatedTask: task,
      closeList: formResult.action === "close_list",
    }
  }

  async function createTask(ctx: ExtensionCommandContext): Promise<Task | null> {
    let createdTask: Task | null = null

    await showTaskForm(ctx, {
      mode: "create",
      subtitle: "Create",
      task: {
        ref: "new",
        title: "",
        description: "",
        status: "open",
        priority: defaultPriority(backend.priorities),
        taskType: defaultTaskType(backend.taskTypes),
      },
      closeKey: CTRL_X,
      cycleStatus: nextStatus,
      cycleTaskType: nextTaskType,
      parsePriorityKey: nextPriorityFromKey,
      priorities: backend.priorities,
      priorityHotkeys: backend.priorityHotkeys,
      onSave: async (draft) => {
        const title = draft.title.trim()
        if (title.length === 0) {
          throw new Error("Title is required")
        }

        if (!createdTask) {
          createdTask = await backend.create({
            title,
            description: draft.description,
            status: draft.status,
            priority: draft.priority,
            taskType: draft.taskType,
          })
          return true
        }

        const update = buildTaskUpdate(createdTask, {
          title,
          description: draft.description,
          status: draft.status,
          priority: draft.priority,
          taskType: draft.taskType,
        })

        if (!hasTaskUpdate(update)) return false

        await updateTask(createdTask.ref, update)
        createdTask = applyDraftToTask(createdTask, {
          title,
          description: draft.description,
          status: draft.status,
          priority: draft.priority,
          taskType: draft.taskType,
        })
        return true
      },
    })

    return createdTask
  }

  async function browseTasks(ctx: ExtensionCommandContext): Promise<void> {
    const pageTitle = "Tasks"
    const backendLabel = backend.id

    try {
      backend.invalidateCache?.()
      ctx.ui.setStatus("tasks", "Loading…")
      const tasks = await listTasks()
      ctx.ui.setStatus("tasks", undefined)

      await showTaskList(ctx, {
        title: pageTitle,
        subtitle: backendLabel,
        tasks,
        closeKey: CTRL_X,
        priorities: backend.priorities,
        priorityHotkeys: backend.priorityHotkeys,
        cycleStatus: nextStatus,
        cycleTaskType: nextTaskType,
        onUpdateTask: updateTask,
        onWork: (task) => pi.sendUserMessage(buildTaskWorkPrompt(task)),
        onInsert: (task) => ctx.ui.pasteToEditor(`${serializeTask(task)} `),
        onEdit: (ref, task) => editTask(ctx, ref, task),
        onCreate: () => createTask(ctx),
      })
    } catch (e) {
      ctx.ui.setStatus("tasks", undefined)
      ctx.ui.notify(e instanceof Error ? e.message : String(e), "error")
    }
  }

  pi.registerCommand("tasks", {
    description: "Open task list",
    handler: async (_rawArgs, ctx) => {
      if (!ctx.hasUI) return
      await browseTasks(ctx)
    },
  })

  pi.registerShortcut("ctrl+x", {
    description: "Open task list",
    handler: async (ctx) => {
      if (!ctx.hasUI) return
      await browseTasks(ctx as ExtensionCommandContext)
    },
  })
}
