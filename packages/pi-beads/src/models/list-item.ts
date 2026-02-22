import { buildTaskListTextParts, type Task } from "./task.ts"

export interface TaskListRowOptions {
  maxLabelWidth?: number
}

export interface TaskListRowModel {
  ref: string
  label: string
  description: string
}

export const DESCRIPTION_PART_SEPARATOR = "\u241F"

function encodeDescription(meta: string, summary?: string): string {
  return summary ? `${meta}${DESCRIPTION_PART_SEPARATOR}${summary}` : meta
}

export function decodeDescription(text: string): { meta: string; summary?: string } {
  const [meta, summary] = text.split(DESCRIPTION_PART_SEPARATOR)
  return { meta: meta || "", summary }
}

export function stripAnsi(str: string): string {
  return str.replace(/\x1b\[[0-9;]*m/g, "")
}

export function buildListRowModel(task: Task, options: TaskListRowOptions = {}): TaskListRowModel {
  const { maxLabelWidth } = options
  const parts = buildTaskListTextParts(task)
  const baseLabel = `${parts.identity} ${parts.title}`
  const visibleWidth = stripAnsi(baseLabel).length

  let label = baseLabel
  if (maxLabelWidth !== undefined && visibleWidth < maxLabelWidth) {
    label += " ".repeat(maxLabelWidth - visibleWidth)
  }

  return {
    ref: task.ref,
    label,
    description: encodeDescription(parts.meta, parts.summary),
  }
}
