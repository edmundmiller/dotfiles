export type TaskStatus = "open" | "inProgress" | "blocked" | "deferred" | "closed"

export interface Task {
  ref: string
  id?: string
  title: string
  description?: string
  status: TaskStatus
  priority?: string
  taskType?: string
  owner?: string
  createdAt?: string
  dueAt?: string
  updatedAt?: string
  dependencyCount?: number
  dependentCount?: number
  commentCount?: number
}

interface TaskListElements {
  id?: string
  title: string
  status: string
  type: string
  summary?: string
}

export interface TaskListTextParts {
  identity: string
  title: string
  meta: string
  summary?: string
}

const PRIORITY_RANK_COLORS = [
  "\x1b[38;5;196m",
  "\x1b[38;5;208m",
  "\x1b[38;5;34m",
  "\x1b[38;5;33m",
  "\x1b[38;5;245m",
]

const STATUS_SYMBOLS: Record<TaskStatus, string> = {
  open: "○",
  inProgress: "◑",
  blocked: "✖",
  deferred: "⏸",
  closed: "✓",
}

const MUTED_TEXT = "\x1b[38;5;245m"
const ANSI_RESET = "\x1b[0m"

function priorityRank(priority: string | undefined): number | undefined {
  if (!priority) return undefined
  const match = priority.toLowerCase().match(/^p(\d)$/)
  if (!match) return undefined
  return Number(match[1])
}

export function formatTaskPriority(priority: string | undefined): string {
  if (priority === undefined || priority === null || priority.length === 0) return "P?"

  const rank = priorityRank(priority)
  const color = rank !== undefined ? PRIORITY_RANK_COLORS[rank] ?? "" : ""
  return `${color}${priority.toUpperCase()}${ANSI_RESET}`
}

function stripIdPrefix(id: string): string {
  const idx = id.indexOf("-")
  return idx >= 0 ? id.slice(idx + 1) : id
}

export function formatTaskTypeCode(taskType: string | undefined): string {
  return (taskType || "task").slice(0, 4).padEnd(4)
}

export function toKebabCase(value: string): string {
  return value.replace(/([a-z])([A-Z])/g, "$1-$2").toLowerCase()
}

export function formatTaskStatusSymbol(status: TaskStatus): string {
  return STATUS_SYMBOLS[status] ?? "?"
}

function firstLine(text: string | undefined): string | undefined {
  if (!text) return undefined
  const line = text.split(/\r?\n/)[0]?.trim()
  return line && line.length > 0 ? line : undefined
}

function buildTaskListElements(task: Task): TaskListElements {
  return {
    id: task.id ? stripIdPrefix(task.id) : undefined,
    title: task.title,
    status: formatTaskStatusSymbol(task.status),
    type: formatTaskTypeCode(task.taskType),
    summary: firstLine(task.description),
  }
}

export function buildTaskIdentityText(priority: string | undefined, idText?: string): string {
  if (!idText) return formatTaskPriority(priority)
  const mutedId = `${MUTED_TEXT}${idText}${ANSI_RESET}`
  return `${formatTaskPriority(priority)} ${mutedId}`
}

export function buildTaskListTextParts(task: Task): TaskListTextParts {
  const elements = buildTaskListElements(task)

  return {
    identity: buildTaskIdentityText(task.priority, elements.id),
    title: elements.title,
    meta: `${elements.status} ${elements.type}`,
    summary: elements.summary,
  }
}
