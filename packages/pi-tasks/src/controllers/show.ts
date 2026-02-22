import type { TaskStatus } from "../models/task.ts"

export type FormFocus = "nav" | "title" | "desc"
export type FormMode = "edit" | "create"

export interface FormDraft {
  title: string
  description: string
  status: TaskStatus
  priority: string | undefined
  taskType: string | undefined
}

type HeaderStatusColor = "dim" | "accent" | "warning"

export interface HeaderStatus {
  message: string
  icon?: string
  color: HeaderStatusColor
}

const FOCUS_LABELS: Record<Exclude<FormFocus, "nav">, string> = {
  title: "Title",
  desc: "Description",
}

export function normalizeDraft(draft: FormDraft): FormDraft {
  return {
    ...draft,
    title: draft.title.trim(),
  }
}

export function isSameDraft(a: FormDraft, b: FormDraft): boolean {
  const left = normalizeDraft(a)
  const right = normalizeDraft(b)
  return (
    left.title === right.title &&
    left.description === right.description &&
    left.status === right.status &&
    left.priority === right.priority &&
    left.taskType === right.taskType
  )
}

export function getHeaderStatus(
  saveIndicator: "saving" | "saved" | "error" | undefined,
  focus: FormFocus,
): HeaderStatus | undefined {
  if (saveIndicator === "saving") return { message: "Saving…", icon: "⟳", color: "dim" }
  if (saveIndicator === "saved") return { message: "Saved", icon: "✓", color: "accent" }
  if (saveIndicator === "error") return { message: "Save failed", color: "warning" }
  if (focus === "title" || focus === "desc") return { message: `Editing ${FOCUS_LABELS[focus].toLowerCase()}`, color: "accent" }
  return undefined
}

export function buildPrimaryHelpText(focus: FormFocus): string {
  if (focus === "title") return "enter save • tab description • esc back"
  if (focus === "desc") return "enter newline • tab save • esc back"
  return "tab title • enter save • esc/q back • ctrl+x close"
}

function buildPriorityHelpText(priorities: string[], priorityHotkeys?: Record<string, string>): string {
  const hotkeyKeys = priorityHotkeys ? Object.keys(priorityHotkeys).sort((a, b) => a.localeCompare(b)) : []
  if (hotkeyKeys.length > 0) {
    return `${hotkeyKeys.join("/")} priority`
  }

  if (priorities.length === 0) return "priority"
  if (priorities.length === 1) return "1 priority"
  return `1-${priorities.length} priority`
}

export function buildSecondaryHelpText(
  focus: FormFocus,
  priorities: string[],
  priorityHotkeys?: Record<string, string>,
): string {
  if (focus !== "nav") return ""
  return `space status • ${buildPriorityHelpText(priorities, priorityHotkeys)} • t type`
}
