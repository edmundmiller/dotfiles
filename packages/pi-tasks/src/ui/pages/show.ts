import { DynamicBorder, type ExtensionCommandContext } from "@mariozechner/pi-coding-agent"
import { Container, Key, Spacer, Text, matchesKey, truncateToWidth, visibleWidth, type Component } from "@mariozechner/pi-tui"
import {
  buildPrimaryHelpText,
  buildSecondaryHelpText,
  getHeaderStatus,
  isSameDraft,
  normalizeDraft,
  type FormDraft,
  type FormFocus,
  type FormMode,
  type HeaderStatus,
} from "../../controllers/show.ts"
import { buildTaskIdentityText, buildTaskListTextParts, formatTaskTypeCode, type Task, type TaskStatus } from "../../models/task.ts"
import { BlurEditorField } from "../components/blur-editor.ts"
import { KEYBOARD_HELP_PADDING_X, formatKeyboardHelp } from "../components/keyboard-help.ts"
import { MinHeightContainer } from "../components/min-height.ts"

export type TaskFormAction = "back" | "close_list"

export interface TaskFormResult {
  action: TaskFormAction
}

interface ShowTaskFormOptions {
  mode: FormMode
  subtitle: string
  task: Task
  closeKey: string
  cycleStatus: (status: TaskStatus) => TaskStatus
  cycleTaskType: (taskType: string | undefined) => string
  parsePriorityKey: (data: string) => string | null
  priorities: string[]
  priorityHotkeys?: Record<string, string>
  onSave: (draft: FormDraft) => Promise<boolean>
}

function buildPageTitle(theme: any, subtitle: string, status?: HeaderStatus): string {
  const base = `${theme.fg("muted", theme.bold("Tasks"))}${theme.fg("dim", ` • ${subtitle}`)}`
  if (!status) return base

  const marker = status.icon ? theme.fg(status.color, status.icon) : "•"
  return `${base} ${marker} ${theme.fg(status.color, status.message)}`
}

function buildSelectedTaskLine(
  mode: FormMode,
  theme: any,
  rowIdentity: string,
  rowMeta: string,
  priority: string | undefined,
  taskType: string | undefined,
): string {
  if (mode === "create") {
    const identity = buildTaskIdentityText(priority, "new")
    return `${theme.fg("accent", SELECTED_ITEM_PREFIX)}${identity} ${formatTaskTypeCode(taskType)}`
  }

  return `${theme.fg("accent", SELECTED_ITEM_PREFIX)}${rowIdentity} ${rowMeta}`
}

function fieldLabel(theme: any, label: string, focused: boolean): string {
  const color = focused ? "accent" : "muted"
  return theme.fg(color, theme.bold(`  ${label}`))
}

const SELECTED_ITEM_PREFIX = "› "
const DESCRIPTION_FIELD_HEIGHT = 8
const PAGE_CONTENT_MIN_HEIGHT = 19

class FixedHeightField implements Component {
  constructor(private child: Component, private height: number) {}

  invalidate(): void {
    this.child.invalidate()
  }

  render(width: number): string[] {
    const lines = this.child.render(width)

    if (lines.length === this.height) return lines

    if (lines.length < this.height) {
      return [...lines, ...Array(this.height - lines.length).fill(" ".repeat(Math.max(0, width)))]
    }

    if (this.height <= 1) {
      return [lines[lines.length - 1] || ""]
    }

    const bottomLine = lines[lines.length - 1] || ""
    const bodyLines = lines.slice(0, lines.length - 1)
    const viewportHeight = this.height - 1

    const cursorIndex = bodyLines.findIndex(line => line.includes("\x1b[7m"))

    let start = Math.max(0, bodyLines.length - viewportHeight)
    if (cursorIndex >= 0) {
      if (cursorIndex < start) {
        start = cursorIndex
      } else if (cursorIndex >= start + viewportHeight) {
        start = cursorIndex - viewportHeight + 1
      }
    }

    const clippedBody = bodyLines.slice(start, start + viewportHeight)
    if (clippedBody.length < viewportHeight) {
      clippedBody.push(...Array(viewportHeight - clippedBody.length).fill(" ".repeat(Math.max(0, width))))
    }

    return [...clippedBody, bottomLine]
  }

  handleInput(data: string): void {
    const childWithInput = this.child as Component & { handleInput?: (input: string) => void }
    childWithInput.handleInput?.(data)
  }
}

class ReservedLineText implements Component {
  private text = ""

  constructor(private paddingX = 1) {}

  setText(text: string): void {
    this.text = text
  }

  invalidate(): void {}

  render(width: number): string[] {
    const innerWidth = Math.max(0, width - this.paddingX * 2)
    const left = " ".repeat(this.paddingX)
    const right = " ".repeat(this.paddingX)

    if (!this.text || this.text.trim().length === 0) {
      return [`${left}${" ".repeat(innerWidth)}${right}`]
    }

    const content = truncateToWidth(this.text, innerWidth)
    const trailingPadding = Math.max(0, innerWidth - visibleWidth(content))
    return [`${left}${content}${" ".repeat(trailingPadding)}${right}`]
  }
}

export async function showTaskForm(ctx: ExtensionCommandContext, options: ShowTaskFormOptions): Promise<TaskFormResult> {
  const { mode, subtitle, task, closeKey, cycleStatus, cycleTaskType, parsePriorityKey, priorities, priorityHotkeys, onSave } = options

  let taskTypeValue = task.taskType
  let titleValue = task.title
  let descValue = task.description ?? ""
  let statusValue = task.status
  let priorityValue = task.priority

  return ctx.ui.custom<TaskFormResult>((tui: any, theme: any, _kb: any, done: any) => {
    const container = new Container()
    const headerContainer = new Container()
    const formContainer = new Container()
    const footerContainer = new Container()
    const paddedFormContainer = new MinHeightContainer(formContainer, PAGE_CONTENT_MIN_HEIGHT)

    container.addChild(headerContainer)
    container.addChild(paddedFormContainer)
    container.addChild(footerContainer)

    const pageTitleText = new Text("", 1, 0)
    const selectedTaskText = new Text("", 0, 0)
    const titleLabel = new Text("", 0, 0)
    const descLabel = new Text("", 0, 0)
    const helpText = new ReservedLineText(KEYBOARD_HELP_PADDING_X)
    const shortcutsText = new ReservedLineText(KEYBOARD_HELP_PADDING_X)

    let focus: FormFocus = mode === "create" ? "title" : "nav"
    let saveIndicator: "saving" | "saved" | "error" | undefined
    let saveIndicatorTimer: ReturnType<typeof setTimeout> | undefined
    let saving = false
    let disposed = false

    const editorTheme = {
      borderColor: (s: string) => theme.fg("accent", s),
      selectList: {
        selectedPrefix: (t: string) => theme.fg("accent", t),
        selectedText: (t: string) => theme.fg("accent", t),
        description: (t: string) => theme.fg("muted", t),
        scrollInfo: (t: string) => theme.fg("dim", t),
        noMatch: (t: string) => theme.fg("warning", t),
      },
    }

    const titleEditor = new BlurEditorField(tui, editorTheme, {
      stripTopBorder: true,
      blurredBorderColor: (s: string) => theme.fg("muted", s),
      paddingX: 2,
      indentX: 2,
    })
    titleEditor.setText(titleValue)
    titleEditor.disableSubmit = true
    titleEditor.onChange = (text: string) => {
      const normalized = text.replace(/\r?\n/g, " ")
      if (normalized !== text) {
        titleEditor.setText(normalized)
        return
      }
      titleValue = normalized
    }

    const descEditor = new BlurEditorField(tui, editorTheme, {
      stripTopBorder: true,
      blurredBorderColor: (s: string) => theme.fg("muted", s),
      paddingX: 2,
      indentX: 2,
    })
    const descEditorField = new FixedHeightField(descEditor, DESCRIPTION_FIELD_HEIGHT)
    descEditor.setText(descValue)
    descEditor.disableSubmit = true
    descEditor.onChange = (text: string) => {
      descValue = text
    }

    const currentDraft = (): FormDraft => ({
      title: titleValue,
      description: descValue,
      status: statusValue,
      priority: priorityValue,
      taskType: taskTypeValue,
    })

    let lastSavedDraft: FormDraft = currentDraft()

    const triggerSave = async () => {
      if (saving || disposed) return

      const draft = currentDraft()
      if (isSameDraft(draft, lastSavedDraft)) return

      saving = true
      if (saveIndicatorTimer) clearTimeout(saveIndicatorTimer)
      saveIndicator = "saving"
      renderLayout()

      try {
        const didSave = await onSave(draft)
        if (disposed) return
        if (!didSave) {
          saveIndicator = undefined
          return
        }
        lastSavedDraft = normalizeDraft(draft)
        saveIndicator = "saved"
      } catch (e) {
        if (disposed) return
        saveIndicator = "error"
        ctx.ui.notify(e instanceof Error ? e.message : String(e), "error")
      } finally {
        saving = false
        if (!disposed) renderLayout()
      }

      if (saveIndicator === "saved" && !disposed) {
        saveIndicatorTimer = setTimeout(() => {
          if (disposed) return
          saveIndicator = undefined
          renderLayout()
        }, 5000)
      }
    }

    const renderLayout = () => {
      titleEditor.focused = focus === "title"
      descEditor.focused = focus === "desc"

      const rowParts = buildTaskListTextParts({
        ...task,
        title: titleValue,
        description: descValue,
        status: statusValue,
        priority: priorityValue,
        taskType: taskTypeValue,
      })

      const headerStatus = getHeaderStatus(saveIndicator, focus)
      pageTitleText.setText(buildPageTitle(theme, subtitle, headerStatus))
      selectedTaskText.setText(
        buildSelectedTaskLine(mode, theme, rowParts.identity, rowParts.meta, priorityValue, taskTypeValue),
      )
      titleLabel.setText(fieldLabel(theme, "Title", focus === "title"))
      descLabel.setText(fieldLabel(theme, "Description", focus === "desc"))

      helpText.setText(formatKeyboardHelp(theme, buildPrimaryHelpText(focus)))
      const secondaryHelp = buildSecondaryHelpText(focus, priorities, priorityHotkeys)
      shortcutsText.setText(secondaryHelp ? formatKeyboardHelp(theme, secondaryHelp) : "")

      container.invalidate()
      tui.requestRender()
    }

    headerContainer.addChild(new DynamicBorder((s: string) => theme.fg("dim", s)))
    headerContainer.addChild(pageTitleText)
    headerContainer.addChild(selectedTaskText)

    formContainer.addChild(new Spacer(1))
    formContainer.addChild(titleLabel)
    formContainer.addChild(titleEditor)
    formContainer.addChild(new Spacer(1))
    formContainer.addChild(descLabel)
    formContainer.addChild(descEditorField)

    footerContainer.addChild(new DynamicBorder((s: string) => theme.fg("dim", s)))
    footerContainer.addChild(helpText)
    footerContainer.addChild(shortcutsText)
    footerContainer.addChild(new DynamicBorder((s: string) => theme.fg("dim", s)))

    renderLayout()

    const requestRender = () => {
      container.invalidate()
      tui.requestRender()
    }

    const handleTitleInput = (data: string) => {
      if (matchesKey(data, Key.enter)) {
        focus = "nav"
        void triggerSave()
        renderLayout()
        return
      }

      if (matchesKey(data, Key.tab)) {
        focus = "desc"
        renderLayout()
        return
      }

      titleEditor.handleInput(data)
      requestRender()
    }

    const handleDescInput = (data: string) => {
      if (matchesKey(data, Key.enter)) {
        descEditor.insertTextAtCursor("\n")
        requestRender()
        return
      }

      if (matchesKey(data, Key.tab)) {
        focus = "nav"
        void triggerSave()
        renderLayout()
        return
      }

      descEditor.handleInput(data)
      requestRender()
    }

    const handleNavInput = (data: string) => {
      if (matchesKey(data, Key.enter)) {
        void triggerSave()
        return
      }

      if (matchesKey(data, Key.tab)) {
        focus = "title"
        renderLayout()
        return
      }

      if (matchesKey(data, Key.escape) || matchesKey(data, Key.left) || data === "q" || data === "Q") {
        done({ action: "back" })
        return
      }

      if (data === "t" || data === "T") {
        taskTypeValue = cycleTaskType(taskTypeValue)
        renderLayout()
        return
      }

      if (data === " ") {
        statusValue = cycleStatus(statusValue)
        renderLayout()
        return
      }

      const priority = parsePriorityKey(data)
      if (priority !== null) {
        priorityValue = priority
        renderLayout()
      }
    }

    return {
      render: (w: number) => container.render(w).map((line: string) => truncateToWidth(line, w)),
      invalidate: () => container.invalidate(),
      dispose: () => {
        disposed = true
        if (saveIndicatorTimer) clearTimeout(saveIndicatorTimer)
      },
      handleInput: (data: string) => {
        if (data === closeKey) {
          done({ action: "close_list" })
          return
        }

        if (focus !== "nav" && matchesKey(data, Key.escape)) {
          focus = "nav"
          renderLayout()
          return
        }

        if (focus === "title") {
          handleTitleInput(data)
          return
        }

        if (focus === "desc") {
          handleDescInput(data)
          return
        }

        handleNavInput(data)
      },
    }
  })
}
