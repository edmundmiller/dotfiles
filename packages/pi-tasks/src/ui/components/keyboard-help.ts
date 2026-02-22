export const KEYBOARD_HELP_PADDING_X = 1

type ThemeLike = {
  fg: (color: string, text: string) => string
}

export function formatKeyboardHelp(theme: ThemeLike, helpText: string): string {
  const trimmed = helpText.trim()
  if (trimmed.length === 0) return ""

  const entries = trimmed.split(" • ").map((entry) => entry.trim()).filter(Boolean)

  return entries
    .map((entry) => {
      const splitIdx = entry.indexOf(" ")
      if (splitIdx === -1) {
        return theme.fg("muted", entry)
      }

      const key = entry.slice(0, splitIdx)
      const action = entry.slice(splitIdx + 1)
      return `${theme.fg("muted", key)} ${theme.fg("dim", action)}`
    })
    .join(theme.fg("dim", " • "))
}
