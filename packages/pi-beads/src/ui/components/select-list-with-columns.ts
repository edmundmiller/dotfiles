import { Key, matchesKey, truncateToWidth, type Component, type SelectItem, type SelectListTheme } from "@mariozechner/pi-tui"

// Local variant of pi-tui SelectList with configurable value/description column layout.

const normalizeToSingleLine = (text: string): string => text.replace(/[\r\n]+/g, " ").trim()

export interface SelectListColumnLayout {
  valueMaxWidth?: number
  valueColumnWidth?: number
  minDescriptionWidth?: number
  minWidthForDescription?: number
}

interface ResolvedSelectListColumnLayout {
  valueMaxWidth: number
  valueColumnWidth: number
  minDescriptionWidth: number
  minWidthForDescription: number
}

const DEFAULT_COLUMN_LAYOUT: ResolvedSelectListColumnLayout = {
  valueMaxWidth: 30,
  valueColumnWidth: 32,
  minDescriptionWidth: 10,
  minWidthForDescription: 40,
}

export class SelectListWithColumns implements Component {
  private items: SelectItem[] = []
  private filteredItems: SelectItem[] = []
  private selectedIndex = 0
  private maxVisible = 5
  private theme: SelectListTheme
  private layout: ResolvedSelectListColumnLayout

  public onSelect?: (item: SelectItem) => void
  public onCancel?: () => void
  public onSelectionChange?: (item: SelectItem) => void

  constructor(items: SelectItem[], maxVisible: number, theme: SelectListTheme, layout: SelectListColumnLayout = {}) {
    this.items = items
    this.filteredItems = items
    this.maxVisible = maxVisible
    this.theme = theme
    this.layout = {
      ...DEFAULT_COLUMN_LAYOUT,
      ...layout,
    }
  }

  setSelectedIndex(index: number): void {
    this.selectedIndex = Math.max(0, Math.min(index, this.filteredItems.length - 1))
  }

  invalidate(): void {
    // No cached state.
  }

  render(width: number): string[] {
    const lines: string[] = []

    if (this.filteredItems.length === 0) {
      lines.push(this.theme.noMatch("  No matching commands"))
      return lines
    }

    const startIndex = Math.max(
      0,
      Math.min(this.selectedIndex - Math.floor(this.maxVisible / 2), this.filteredItems.length - this.maxVisible),
    )
    const endIndex = Math.min(startIndex + this.maxVisible, this.filteredItems.length)

    for (let i = startIndex; i < endIndex; i++) {
      const item = this.filteredItems[i]
      if (!item) continue

      const isSelected = i === this.selectedIndex
      const descriptionSingleLine = item.description ? normalizeToSingleLine(item.description) : undefined
      const displayValue = item.label || item.value
      const prefix = isSelected ? "→ " : "  "

      if (!descriptionSingleLine || width <= this.layout.minWidthForDescription) {
        lines.push(this.renderValueOnlyLine(prefix, displayValue, width, isSelected))
        continue
      }

      const maxValueWidth = Math.min(this.layout.valueMaxWidth, width - prefix.length - 4)
      const truncatedValue = truncateToWidth(displayValue, maxValueWidth, "")
      const spacing = " ".repeat(Math.max(1, this.layout.valueColumnWidth - truncatedValue.length))
      const descriptionStart = prefix.length + truncatedValue.length + spacing.length
      const descriptionWidth = width - descriptionStart - 2

      if (descriptionWidth <= this.layout.minDescriptionWidth) {
        lines.push(this.renderValueOnlyLine(prefix, displayValue, width, isSelected))
        continue
      }

      const truncatedDesc = truncateToWidth(descriptionSingleLine, descriptionWidth, "")
      if (isSelected) {
        lines.push(this.theme.selectedText(`${prefix}${truncatedValue}${spacing}${truncatedDesc}`))
      } else {
        lines.push(`${prefix}${truncatedValue}${this.theme.description(spacing + truncatedDesc)}`)
      }
    }

    if (startIndex > 0 || endIndex < this.filteredItems.length) {
      const scrollText = `  (${this.selectedIndex + 1}/${this.filteredItems.length})`
      lines.push(this.theme.scrollInfo(truncateToWidth(scrollText, width - 2, "")))
    }

    return lines
  }

  handleInput(keyData: string): void {
    if (matchesKey(keyData, Key.up)) {
      this.selectedIndex = this.selectedIndex === 0 ? this.filteredItems.length - 1 : this.selectedIndex - 1
      this.notifySelectionChange()
      return
    }

    if (matchesKey(keyData, Key.down)) {
      this.selectedIndex = this.selectedIndex === this.filteredItems.length - 1 ? 0 : this.selectedIndex + 1
      this.notifySelectionChange()
      return
    }

    if (matchesKey(keyData, Key.enter)) {
      const selectedItem = this.filteredItems[this.selectedIndex]
      if (selectedItem && this.onSelect) this.onSelect(selectedItem)
      return
    }

    if (matchesKey(keyData, Key.escape) || keyData === "\u0003") {
      if (this.onCancel) this.onCancel()
    }
  }

  getSelectedItem(): SelectItem | null {
    const item = this.filteredItems[this.selectedIndex]
    return item || null
  }

  private renderValueOnlyLine(prefix: string, displayValue: string, width: number, isSelected: boolean): string {
    const maxWidth = width - prefix.length - 2
    const line = `${prefix}${truncateToWidth(displayValue, maxWidth, "")}`
    return isSelected ? this.theme.selectedText(line) : line
  }

  private notifySelectionChange(): void {
    const selectedItem = this.filteredItems[this.selectedIndex]
    if (selectedItem && this.onSelectionChange) this.onSelectionChange(selectedItem)
  }
}
