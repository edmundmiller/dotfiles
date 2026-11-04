// Supported legacy keybindings, after the Ctrl+C prefix (not simultaneous chords).
export const prefixBindings = [
  { key: "shift-n", label: "New space", command: "space.new" },
  { key: "g", label: "New Git worktree", special: "worktree", action: "new" },
  { key: "shift-g", label: "Open Git worktree", special: "worktree", action: "open" },
  { key: "/", label: "Go to tab, space or agent", command: "mod.open", args: { name: "picker" } },
  { key: "w", command: "mod.open", args: { name: "picker" } },
  { key: "s", label: "Split down", command: "pane.split", args: { direction: "down" } },
  { key: "v", label: "Split right", command: "pane.split", args: { direction: "right" } },
  { key: "b", label: "Toggle sidebar", command: "layout.toggle", args: { id: "sidebar" } },
  { key: "shift-b", label: "T3 sidebar mode", command: "t3-chrome.sidebar", layout: "herdr-t3" },
  { key: "shift-a", label: "T3 agent view", command: "t3-tabs.view", layout: "herdr-t3" },
  {
    key: "shift-s",
    label: "T3 settle/unsettle agent",
    command: "t3-focus.settle",
    layout: "herdr-t3",
  },
  { key: "p", label: "Previous tab", command: "tab.prev" },
  { key: "n", label: "Next tab", command: "tab.next" },
  { key: ",", label: "Settings", command: "app.settings" },
  { key: "c", label: "New tab", command: "tab.new" },
  { key: "alt-t", label: "Rename tab", command: "tab.rename" },
  { key: "h", label: "Focus left", command: "pane.go", args: { direction: "left" } },
  { key: "j", label: "Focus down", command: "pane.go", args: { direction: "down" } },
  { key: "k", label: "Focus up", command: "pane.go", args: { direction: "up" } },
  { key: "l", label: "Focus right", command: "pane.go", args: { direction: "right" } },
  { key: "tab", label: "Next pane", special: "cycle", step: 1 },
  { key: "shift-tab", label: "Previous pane", special: "cycle", step: -1 },
  { key: "x", label: "Close pane", command: "pane.close" },
  { key: "shift-x", label: "Close tab", command: "tab.close" },
  { key: "z", label: "Zoom pane", command: "pane.zoom" },
  { key: "shift-j", label: "Next agent", command: "agent.next" },
  { key: "shift-k", label: "Previous agent", command: "agent.prev" },
  { key: "shift-left", label: "Move tab left", special: "move-tab", step: -1 },
  { key: "shift-right", label: "Move tab right", special: "move-tab", step: 1 },
  { key: "m", label: "Command palette", command: "app.palette" },
  { key: "space", label: "Show prefix help", special: "help" },
  { key: "f", label: "Show Files panel", special: "files" },
  { key: "]", label: "Review worktree in Hunk", special: "hunk" },
  { key: "}", label: "Review staged changes in Hunk", special: "hunk", args: ["--staged"] },
  { key: "{", label: "Review branch in Hunk", special: "hunk", args: ["--branch", "origin/main"] },
  { key: "shift-v", label: "Open Obsidian in Neovide", special: "obsidian" },
  { key: "escape", special: "cancel" },
  { key: "ctrl-[", special: "cancel" },
  { key: "q", special: "cancel" },
  { key: "ctrl-c", special: "interrupt" },
  ...Array.from({ length: 9 }, (_, offset) => {
    const index = offset + 1;
    return [
      { key: String(index), label: `Tab ${index}`, command: "tab.select", args: { index } },
      { key: `shift-${index}`, command: "space.select", args: { index } },
      { key: `alt-${index}`, special: "agent", index },
    ];
  }).flat(),
];

// Normalize shifted letters, digits and punctuation from GPUI keyboard events.
export function normalizePrefixKey(event) {
  const modifiers = event.modifiers || {};
  const key = event.key;
  if (modifiers.shift && !modifiers.control && !modifiers.alt && !modifiers.platform) {
    const digits = "!@#$%^&*(";
    if (digits.includes(key) && key.length === 1) return `shift-${digits.indexOf(key) + 1}`;
    if (event.key_char === "{" || event.key_char === "}") return event.key_char;
    if (key === "{" || key === "}") return key;
    if (key.length === 1 && /[a-zA-Z0-9]/.test(key)) return `shift-${key.toLowerCase()}`;
  }
  return event.keystroke === "comma" ? "," : event.keystroke;
}
