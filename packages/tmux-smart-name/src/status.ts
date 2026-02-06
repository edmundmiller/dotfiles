/**
 * AI agent status detection via pane content analysis.
 */

export type StatusIcon = "□" | "●" | "■" | "▲" | "◇";

export const ICON_IDLE: StatusIcon = "□";
export const ICON_BUSY: StatusIcon = "●";
export const ICON_WAITING: StatusIcon = "■";
export const ICON_ERROR: StatusIcon = "▲";
export const ICON_UNKNOWN: StatusIcon = "◇";

export const ICON_COLORS: Record<StatusIcon, string> = {
  "□": "#[fg=blue]□#[default]",
  "●": "#[fg=cyan]●#[default]",
  "■": "#[fg=yellow]■#[default]",
  "▲": "#[fg=red]▲#[default]",
  "◇": "#[fg=magenta]◇#[default]",
};

export function colorize(icon: StatusIcon): string {
  return ICON_COLORS[icon] ?? icon;
}

// ── ANSI stripping ─────────────────────────────────────────────────────────

const ANSI_RE = /\x1b\[[0-9;]*[a-zA-Z]/g;
const OSC_RE = /\x1b\][^\x07]*\x07/g;
const DCS_RE = /\x1b[PX^_][^\x1b]*\x1b\\/g;
const CTRL_RE = /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]/g;

export function stripAnsi(text: string): string {
  return text.replace(ANSI_RE, "").replace(OSC_RE, "").replace(DCS_RE, "").replace(CTRL_RE, "");
}

// ── Pattern sets ───────────────────────────────────────────────────────────

const ERROR_PATTERNS = [
  /Traceback \(most recent call last\)/,
  /UnhandledPromiseRejection/i,
  /FATAL ERROR/i,
  /panic:/,
  /Error: .*(API|rate limit|connection|timeout)/i,
  /(?:opencode|claude).*(?:crashed|failed|error)/i,
];

const WAITING_PATTERNS = [
  /Allow (?:once|always)\?/i,
  /Do you want to (?:run|execute|allow)/i,
  /(?:Approve|Confirm|Accept)\?.*\[Y\/n\]/i,
  /Press enter to continue/i,
  /Waiting for (?:input|approval|confirmation)/i,
  /Permission required/i,
  /(?:yes|no|skip)\s*›/i,
];

const BUSY_PATTERNS = [
  /Thinking\.{2,}/i,
  /(?:Running|Executing|Processing)\.{2,}/i,
  /[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/,
  /Working on/i,
  /Analyzing/i,
  /Reading (?:file|files)/i,
  /Writing (?:to|file)/i,
  /Searching/i,
  /Calling tool/i,
  /Tool:/i,
  /⎿/,
  /Running tools/i,
  /≋/,
  /■■■/,
  /esc interrupt/i,
  /Esc to cancel/i,
];

const IDLE_PATTERNS = [
  />\s*$/m,
  /❯\s*$/m,
  /│\s*$/m,
  /What would you like/i,
  /How can I help/i,
  /Session went idle/i,
  /Finished\s*$/im,
  /Done\.\s*$/im,
  /completed successfully/i,
  /\d+% of \d+k/,
  /OpenCode \d+\.\d+\.\d+/,
  /ctrl\+p commands/i,
];

function matchesAny(content: string, patterns: RegExp[]): boolean {
  return patterns.some((p) => p.test(content));
}

// ── Public API ─────────────────────────────────────────────────────────────

export function detectStatus(content: string): StatusIcon {
  if (!content?.trim()) return ICON_UNKNOWN;

  const clean = stripAnsi(content);

  if (matchesAny(clean, ERROR_PATTERNS)) return ICON_ERROR;
  if (matchesAny(clean, WAITING_PATTERNS)) return ICON_WAITING;
  if (matchesAny(clean, BUSY_PATTERNS)) return ICON_BUSY;
  if (matchesAny(clean, IDLE_PATTERNS)) return ICON_IDLE;

  return ICON_UNKNOWN;
}

/** ERROR > UNKNOWN > WAITING > BUSY > IDLE */
const PRIORITY: Record<StatusIcon, number> = {
  "▲": 0,
  "◇": 1,
  "■": 2,
  "●": 3,
  "□": 4,
};

export function prioritize(statuses: StatusIcon[]): StatusIcon {
  if (statuses.length === 0) return ICON_IDLE;
  return statuses.reduce((best, s) => (PRIORITY[s] < PRIORITY[best] ? s : best));
}
