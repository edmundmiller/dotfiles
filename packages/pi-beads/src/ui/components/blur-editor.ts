import { Editor, Text, type Component, type EditorTheme, type Focusable } from "@mariozechner/pi-tui"

interface BlurEditorFieldOptions {
  stripTopBorder?: boolean
  blurredBorderColor?: (str: string) => string
  paddingX?: number
  indentX?: number
}

export class BlurEditorField implements Component, Focusable {
  focused = false
  onChange?: (text: string) => void

  private editor: Editor
  private previewText: Text
  private stripTopBorder: boolean
  private blurredBorderColor: (str: string) => string
  private indentX: number

  constructor(tui: any, theme: EditorTheme, options: BlurEditorFieldOptions = {}) {
    const paddingX = options.paddingX ?? 1

    this.editor = new Editor(tui, theme)
    this.editor.setPaddingX(paddingX)
    this.previewText = new Text("", paddingX, 0)
    this.stripTopBorder = options.stripTopBorder ?? true
    this.blurredBorderColor = options.blurredBorderColor ?? theme.borderColor
    this.indentX = Math.max(0, options.indentX ?? 0)

    this.editor.onChange = (text: string) => {
      this.onChange?.(text)
    }
  }

  set disableSubmit(value: boolean) {
    this.editor.disableSubmit = value
  }

  setText(text: string): void {
    this.editor.setText(text)
  }

  getText(): string {
    return this.editor.getText()
  }

  insertTextAtCursor(text: string): void {
    this.editor.insertTextAtCursor(text)
  }

  invalidate(): void {
    this.editor.invalidate()
    this.previewText.invalidate()
  }

  render(width: number): string[] {
    const innerWidth = Math.max(1, width - this.indentX)
    const indent = " ".repeat(this.indentX)
    const withIndent = (lines: string[]) => lines.map(line => `${indent}${line}`)

    if (!this.focused) {
      this.previewText.setText(this.editor.getText())
      const contentLines = this.previewText.render(innerWidth)
      const lines = contentLines.length > 0 ? contentLines : [" ".repeat(Math.max(0, innerWidth))]
      const borderLine = this.blurredBorderColor("─".repeat(Math.max(0, innerWidth)))
      return withIndent([...lines, borderLine])
    }

    const lines = this.editor.render(innerWidth)
    const visibleLines = !this.stripTopBorder || lines.length <= 1 ? lines : lines.slice(1)
    return withIndent(visibleLines)
  }

  handleInput(data: string): void {
    if (!this.focused) return
    this.editor.handleInput(data)
  }
}
