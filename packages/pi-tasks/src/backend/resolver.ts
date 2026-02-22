import type { ExtensionAPI } from "@mariozechner/pi-coding-agent"
import { readdir } from "node:fs/promises"
import { dirname, extname, join } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"
import type { TaskAdapter, TaskAdapterInitializer } from "./api.ts"

const ADAPTERS_DIRECTORY = join(dirname(fileURLToPath(import.meta.url)), "adapters")
const SUPPORTED_ADAPTER_EXTENSIONS = new Set([".ts", ".js", ".mjs", ".cjs"])

function isTaskAdapterInitializer(value: unknown): value is TaskAdapterInitializer {
  if (!value || typeof value !== "object") return false

  const candidate = value as {
    id?: unknown
    isApplicable?: unknown
    initialize?: unknown
  }

  return (
    typeof candidate.id === "string" &&
    typeof candidate.isApplicable === "function" &&
    typeof candidate.initialize === "function"
  )
}

async function loadAdapterInitializers(): Promise<TaskAdapterInitializer[]> {
  const entries = await readdir(ADAPTERS_DIRECTORY, { withFileTypes: true })
  const adapterFiles = entries
    .filter(entry => entry.isFile())
    .map(entry => entry.name)
    .filter(name => SUPPORTED_ADAPTER_EXTENSIONS.has(extname(name)))
    .sort((a, b) => a.localeCompare(b))

  const adapters: TaskAdapterInitializer[] = []

  for (const fileName of adapterFiles) {
    const modulePath = pathToFileURL(join(ADAPTERS_DIRECTORY, fileName)).href
    const module = await import(modulePath)
    const initializer = module.default

    if (!isTaskAdapterInitializer(initializer)) {
      throw new Error(`Invalid adapter export in ${fileName}: expected default TaskAdapterInitializer`)
    }

    adapters.push(initializer)
  }

  if (adapters.length === 0) {
    throw new Error(`No task adapters found in ${ADAPTERS_DIRECTORY}`)
  }

  const ids = new Set<string>()
  for (const adapter of adapters) {
    if (ids.has(adapter.id)) {
      throw new Error(`Duplicate task adapter id detected: ${adapter.id}`)
    }
    ids.add(adapter.id)
  }

  return adapters
}

const ADAPTER_INITIALIZERS = await loadAdapterInitializers()

function lookup(): TaskAdapterInitializer {
  const configuredAdapterId = process.env.PI_TASKS_BACKEND?.trim()
  if (configuredAdapterId) {
    const configured = ADAPTER_INITIALIZERS.find(adapter => adapter.id === configuredAdapterId)
    if (!configured) {
      throw new Error(`Unsupported tasks backend: ${configuredAdapterId}`)
    }
    return configured
  }

  const detected = ADAPTER_INITIALIZERS.find(adapter => adapter.isApplicable())
  if (detected) return detected

  const fallback = ADAPTER_INITIALIZERS.find(adapter => adapter.id === "todo-md")
  if (fallback) return fallback

  return ADAPTER_INITIALIZERS[0]
}

export default function initializeAdapter(pi: ExtensionAPI): TaskAdapter {
  return lookup().initialize(pi)
}
