import type { Component } from "@mariozechner/pi-tui"

export class MinHeightContainer implements Component {
  constructor(private child: Component, private minHeight: number) {}

  invalidate(): void {
    this.child.invalidate()
  }

  render(width: number): string[] {
    const lines = this.child.render(width)
    if (lines.length >= this.minHeight) return lines
    const padLine = " ".repeat(Math.max(0, width))
    return [...lines, ...Array(this.minHeight - lines.length).fill(padLine)]
  }

  handleInput(data: string): void {
    const childWithInput = this.child as Component & { handleInput?: (input: string) => void }
    childWithInput.handleInput?.(data)
  }
}
