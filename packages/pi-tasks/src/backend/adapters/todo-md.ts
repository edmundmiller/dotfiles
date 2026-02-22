import type { ExtensionAPI } from "@mariozechner/pi-coding-agent"
import { createHash, randomUUID } from "node:crypto"
import { existsSync } from "node:fs"
import { mkdir, readFile, writeFile } from "node:fs/promises"
import { dirname, resolve } from "node:path"
import type { Task, TaskStatus } from "../../models/task.ts"
import type { CreateTaskInput, TaskAdapter, TaskAdapterInitializer, TaskStatusMap, TaskUpdate } from "../api.ts"

const DEFAULT_TODO_FILES = ["TODO.md", "todo.md"] as const
const TODO_FILE_ENV = "PI_TASKS_TODO_PATH"
const SECTION_ORDER = ["now", "next", "later", "archive"] as const
const OPEN_PRIORITIES = ["now", "next", "later"] as const
const DEFAULT_TODO_TITLE = "TODO"

const STATUS_MAP = {
  open: "open",
  closed: "done",
} satisfies TaskStatusMap

type TodoSection = typeof SECTION_ORDER[number]
type TodoPriority = typeof OPEN_PRIORITIES[number]

interface TodoTaskRecord {
  ref: string
  title: string
  description: string
  status: TaskStatus
  priority: TodoPriority | undefined
}

interface TodoDocument {
  title: string
  format: "structured" | "flat"
  tasks: TodoTaskRecord[]
}

function configuredTodoPath(): string {
  const fromEnv = process.env[TODO_FILE_ENV]?.trim()
  if (fromEnv && fromEnv.length > 0) return fromEnv

  const existingDefault = DEFAULT_TODO_FILES.find(file => existsSync(resolve(process.cwd(), file)))
  return existingDefault ?? DEFAULT_TODO_FILES[0]
}

function resolveTodoPath(): string {
  return resolve(process.cwd(), configuredTodoPath())
}

function sectionToPriority(section: TodoSection): TodoPriority | undefined {
  if (section === "archive") return undefined
  return section
}

function headingToSection(line: string): TodoSection | null {
  const match = line.match(/^##\s+(now|next|later|archive)\s*$/i)
  if (!match) return null
  return match[1]!.toLowerCase() as TodoSection
}

function parseTaskLine(line: string): { checked: boolean; title: string; inlineDescription: string } | null {
  const match = line.match(/^\s*-\s*\[( |x|X)\]\s*(?:\*\*(.+?)\*\*|(.+?))(?:\s*[—-]\s*(.+))?\s*$/)
  if (!match) return null

  return {
    checked: match[1]!.toLowerCase() === "x",
    title: (match[2] ?? match[3] ?? "").trim(),
    inlineDescription: (match[4] ?? "").trim(),
  }
}

function parseDescriptionBullet(line: string): string | null {
  const match = line.match(/^\s{2,}-\s+(.+)$/)
  if (!match) return null
  return `- ${match[1]!.trim()}`
}

function computeTaskRef(title: string, description: string, occurrence: number): string {
  const digest = createHash("sha1")
    .update(title.trim())
    .update("\n")
    .update(description.trim())
    .digest("hex")
    .slice(0, 10)

  return `todo-${digest}-${occurrence}`
}

function createNewTaskRef(existingRefs: Set<string>): string {
  let candidate = `todo-${randomUUID().slice(0, 8)}`
  while (existingRefs.has(candidate)) {
    candidate = `todo-${randomUUID().slice(0, 8)}`
  }
  return candidate
}

function assignTaskRefs(tasks: Omit<TodoTaskRecord, "ref">[]): TodoTaskRecord[] {
  const seen = new Map<string, number>()

  return tasks.map((task) => {
    const key = `${task.title.trim()}\n${task.description.trim()}`
    const nextOccurrence = (seen.get(key) ?? 0) + 1
    seen.set(key, nextOccurrence)

    return {
      ...task,
      ref: computeTaskRef(task.title, task.description, nextOccurrence),
    }
  })
}

function extractTitle(lines: string[]): string {
  const heading = lines.find(line => /^#\s+/.test(line.trim()))
  if (!heading) return DEFAULT_TODO_TITLE
  return heading.replace(/^#\s+/, "").trim() || DEFAULT_TODO_TITLE
}

function parseChecklistTasks(
  lines: string[],
  resolvePriority: (section: TodoSection | null) => TodoPriority | undefined,
): Omit<TodoTaskRecord, "ref">[] {
  const parsedTasks: Omit<TodoTaskRecord, "ref">[] = []

  let section: TodoSection | null = null
  let activeTask: {
    checked: boolean
    title: string
    inlineDescription: string
    bullets: string[]
    section: TodoSection | null
  } | null = null

  const flushActiveTask = () => {
    if (!activeTask) return

    const description = activeTask.bullets.length > 0
      ? activeTask.bullets.join("\n")
      : activeTask.inlineDescription

    parsedTasks.push({
      title: activeTask.title,
      description,
      status: activeTask.checked ? "closed" : "open",
      priority: activeTask.checked ? undefined : resolvePriority(activeTask.section),
    })

    activeTask = null
  }

  for (const line of lines) {
    const nextSection = headingToSection(line)
    if (nextSection) {
      flushActiveTask()
      section = nextSection
      continue
    }

    const taskLine = parseTaskLine(line)
    if (taskLine) {
      flushActiveTask()
      activeTask = {
        ...taskLine,
        bullets: [],
        section,
      }
      continue
    }

    if (!activeTask) continue

    const bullet = parseDescriptionBullet(line)
    if (bullet) {
      activeTask.bullets.push(bullet)
      continue
    }

    if (line.trim().length === 0) continue

    flushActiveTask()
  }

  flushActiveTask()

  return parsedTasks
}

function parseTodoDocument(content: string): TodoDocument {
  const lines = content.split(/\r?\n/)
  const title = extractTitle(lines)
  const hasStructuredSections = lines.some(line => headingToSection(line) !== null)

  if (hasStructuredSections) {
    const tasks = parseChecklistTasks(lines, section => sectionToPriority(section ?? "now") ?? "now")
    return {
      title,
      format: "structured",
      tasks: assignTaskRefs(tasks),
    }
  }

  const tasks = parseChecklistTasks(lines, () => "now")
  return {
    title,
    format: "flat",
    tasks: assignTaskRefs(tasks),
  }
}

function asBulletLines(description: string): string[] {
  const normalized = description
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(line => line.length > 0)

  if (normalized.length === 0) return []

  return normalized.map(line => line.startsWith("- ") ? line : `- ${line}`)
}

function taskToMarkdownLine(task: TodoTaskRecord): string[] {
  const checked = task.status === "closed" ? "x" : " "
  const title = task.title.trim()
  const description = task.description.trim()

  if (description.length === 0) {
    return [`- [${checked}] **${title}**`]
  }

  const descriptionLines = description.split(/\r?\n/).map(line => line.trim()).filter(Boolean)
  if (descriptionLines.length === 1 && !descriptionLines[0]!.startsWith("- ")) {
    return [`- [${checked}] **${title}** — ${descriptionLines[0]}`]
  }

  const lines = [`- [${checked}] **${title}**`]
  for (const bullet of asBulletLines(description)) {
    lines.push(`  ${bullet}`)
  }
  return lines
}

function renderStructuredDocument(document: TodoDocument): string {
  const sectionTasks: Record<TodoSection, TodoTaskRecord[]> = {
    now: [],
    next: [],
    later: [],
    archive: [],
  }

  for (const task of document.tasks) {
    if (task.status === "closed") {
      sectionTasks.archive.push(task)
      continue
    }

    const priority = task.priority ?? "now"
    sectionTasks[priority].push(task)
  }

  const lines: string[] = [`# ${document.title}`, ""]

  const sectionTitleById: Record<TodoSection, string> = {
    now: "Now",
    next: "Next",
    later: "Later",
    archive: "Archive",
  }

  for (const section of SECTION_ORDER) {
    lines.push(`## ${sectionTitleById[section]}`)
    lines.push("")

    for (const task of sectionTasks[section]) {
      lines.push(...taskToMarkdownLine(task))
    }

    lines.push("")
  }

  return `${lines.join("\n").trimEnd()}\n`
}

function renderFlatDocument(document: TodoDocument): string {
  const lines: string[] = [`# ${document.title}`, ""]

  const openTasks = document.tasks.filter(task => task.status === "open")
  for (const task of openTasks) {
    lines.push(...taskToMarkdownLine(task))
  }

  const archivedTasks = document.tasks.filter(task => task.status === "closed")
  if (archivedTasks.length > 0) {
    lines.push("", "## Archive", "")
    for (const task of archivedTasks) {
      lines.push(...taskToMarkdownLine(task))
    }
  }

  lines.push("")
  return `${lines.join("\n").trimEnd()}\n`
}

function renderTodoDocument(document: TodoDocument): string {
  const shouldUseStructured = document.format === "structured" || document.tasks.some(task => (
    task.status === "open" && task.priority !== undefined && task.priority !== "now"
  ))

  return shouldUseStructured
    ? renderStructuredDocument(document)
    : renderFlatDocument(document)
}

function normalizePriority(priority: string | undefined): TodoPriority | undefined {
  if (!priority) return undefined
  const normalized = priority.toLowerCase()
  if (normalized === "now" || normalized === "next" || normalized === "later") return normalized
  return undefined
}

function toTask(task: TodoTaskRecord): Task {
  return {
    ref: task.ref,
    title: task.title,
    description: task.description,
    status: task.status,
    priority: task.priority,
    taskType: "task",
  }
}

function normalizeStatus(status: TaskStatus | undefined): TaskStatus {
  if (status === "closed") return "closed"
  return "open"
}

function applyTaskUpdate(task: TodoTaskRecord, update: TaskUpdate): TodoTaskRecord {
  const nextTitle = update.title !== undefined ? update.title.trim() : task.title
  const nextDescription = update.description !== undefined ? update.description : task.description
  const nextStatus = update.status !== undefined ? normalizeStatus(update.status) : task.status
  const nextPriority = update.priority !== undefined
    ? normalizePriority(update.priority) ?? task.priority
    : task.priority

  return {
    ...task,
    title: nextTitle,
    description: nextDescription,
    status: nextStatus,
    priority: nextStatus === "closed" ? undefined : (nextPriority ?? "now"),
  }
}

async function readDocument(filePath: string): Promise<TodoDocument> {
  try {
    const content = await readFile(filePath, "utf8")
    return parseTodoDocument(content)
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      return { title: DEFAULT_TODO_TITLE, format: "structured", tasks: [] }
    }
    throw error
  }
}

async function writeDocument(filePath: string, document: TodoDocument): Promise<void> {
  await mkdir(dirname(filePath), { recursive: true })
  await writeFile(filePath, renderTodoDocument(document), "utf8")
}

function isApplicable(): boolean {
  return existsSync(resolveTodoPath())
}

function initialize(_pi: ExtensionAPI): TaskAdapter {
  const filePath = resolveTodoPath()
  let documentCache: TodoDocument | null = null

  async function getDocument(): Promise<TodoDocument> {
    if (documentCache) return documentCache
    documentCache = await readDocument(filePath)
    return documentCache
  }

  async function persistDocument(document: TodoDocument): Promise<void> {
    documentCache = document
    await writeDocument(filePath, document)
  }

  return {
    id: "todo-md",
    statusMap: STATUS_MAP,
    taskTypes: ["task"],
    priorities: [...OPEN_PRIORITIES],
    invalidateCache: () => {
      documentCache = null
    },

    async list(): Promise<Task[]> {
      const document = await getDocument()
      return document.tasks
        .filter(task => task.status === "open")
        .map(toTask)
    },

    async show(ref: string): Promise<Task> {
      const document = await getDocument()
      const task = document.tasks.find(item => item.ref === ref)
      if (!task) throw new Error(`Task not found: ${ref}`)
      return toTask(task)
    },

    async update(ref: string, update: TaskUpdate): Promise<void> {
      const document = await getDocument()
      const index = document.tasks.findIndex(task => task.ref === ref)
      if (index === -1) throw new Error(`Task not found: ${ref}`)

      const updatedTasks = [...document.tasks]
      updatedTasks[index] = applyTaskUpdate(updatedTasks[index]!, update)

      await persistDocument({ ...document, tasks: updatedTasks })
    },

    async create(input: CreateTaskInput): Promise<Task> {
      const document = await getDocument()

      const status = normalizeStatus(input.status)
      const existingRefs = new Set(document.tasks.map(task => task.ref))
      const createdTask: TodoTaskRecord = {
        ref: createNewTaskRef(existingRefs),
        title: input.title.trim(),
        description: input.description ?? "",
        status,
        priority: status === "closed"
          ? undefined
          : (normalizePriority(input.priority) ?? "now"),
      }

      await persistDocument({ ...document, tasks: [...document.tasks, createdTask] })
      return toTask(createdTask)
    },
  }
}

export default {
  id: "todo-md",
  isApplicable,
  initialize,
} satisfies TaskAdapterInitializer
