/**
 * AI agent status detection via pane content analysis.
 *
 * Pattern priority: ERROR > WAITING > BUSY > IDLE > UNKNOWN
 * Agent-specific patterns are checked first, then shared fallbacks.
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

// ── Shared patterns (all agents) ───────────────────────────────────────────

const SHARED_ERROR = [
  /Traceback \(most recent call last\)/,
  /UnhandledPromiseRejection/i,
  /FATAL ERROR/i,
  /panic:/,
  /Error: .*(API|rate limit|connection|timeout)/i,
];

const SHARED_WAITING = [
  /Allow (?:once|always)\?/i,
  /Do you want to (?:run|execute|allow)/i,
  /(?:Approve|Confirm|Accept)\?.*\[Y\/n\]/i,
  /Press enter to continue/i,
  /Waiting for (?:input|approval|confirmation)/i,
  /Permission required/i,
  /(?:yes|no|skip)\s*›/i,
];

const SHARED_BUSY = [
  /[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/, // braille spinners
  /Thinking\.{2,}/i,
  /(?:Running|Executing|Processing)\.{2,}/i,
  /Working on/i,
  /Analyzing/i,
  /Reading (?:file|files)/i,
  /Writing (?:to|file)/i,
  /Searching/i,
  /Calling tool/i,
];

// ── pi patterns ────────────────────────────────────────────────────────────
// Source: pi-coding-agent/dist/modes/interactive/

const PI_BUSY_STRONG = [
  /Working\.\.\./i, // Loader component: "⠦ Working... (Escape to interrupt)"
  /to interrupt\)/i, // Loader suffix: "(Escape to interrupt)"
  /Auto-compacting\.\.\./i, // "⠦ Auto-compacting... (Escape to cancel)"
  /Retrying \(\d+\/\d+\)/i, // "⠦ Retrying (1/3) in 5s..."
  /Summarizing branch\.\.\./i, // "⠦ Summarizing branch... (Escape to cancel)"
  /Steering:/i, // queued steering message (agent still processing)
  /Follow-up:/i, // queued follow-up message (agent still processing)
  /to edit all queued/i, // "↳ Alt+Up to edit all queued messages"
];

// Weak busy indicators that can linger in scrollback while pi is idle.
// These should not override explicit footer idle signals.
const PI_BUSY_WEAK = [
  /earlier lines,/i, // "... (3 earlier lines, ctrl+o to expand)"
  /more lines,/i, // "... (5 more lines, ctrl+o to expand)"
];

const PI_IDLE = [
  // Footer: "(provider) model-name • thinking-level"
  /\(anthropic\)\s+\S+/i,
  /\(openai[^)]*\)\s+\S+/i,
  /\(google\)\s+\S+/i,
  // Footer stats: "↑343 ↓20k R11M W820k $10.960 (sub) 13.9%/1.0M (auto)"
  /↑\d+k?\s+↓\d+k?/,
  /\$\d+\.\d{3}/i, // cost: "$10.960"
  /\d+\.\d+%\/\d+k?\s+\(auto\)/, // context: "13.9%/1.0M (auto)"
  // Extension statuses in footer
  /\bLSP\b/,
  /\bMCP:/,
];

// ── Claude Code patterns ───────────────────────────────────────────────────

const CLAUDE_BUSY = [
  /⎿/, // Claude tool output marker
  /Esc to cancel/i, // shown during tool execution
];

const CLAUDE_IDLE = [
  />\s*$/m, // prompt line ">"
  /What would you like/i,
  /How can I help/i,
  /\d+% of \d+k/, // token usage: "45% of 168k"
];

// ── Amp patterns ───────────────────────────────────────────────────────────

const AMP_BUSY = [
  /≋/, // amp streaming indicator
  /■■■/, // amp progress bar
  /esc interrupt/i, // shown during tool execution
  /Running tools/i,
];

const AMP_IDLE = [
  /ctrl\+p commands/i, // amp footer hint
  /ctrl\+t variants/i, // amp footer hint
];

// ── OpenCode patterns ──────────────────────────────────────────────────────

const OPENCODE_BUSY = [
  /Tool:/i, // tool execution
];

const OPENCODE_IDLE = [
  /OpenCode \d+\.\d+\.\d+/, // version in status bar
];

// ── Detection logic ────────────────────────────────────────────────────────

interface PatternSet {
  error: RegExp[];
  waiting: RegExp[];
  busy: RegExp[];
  idle: RegExp[];
}

const AGENT_PATTERNS: Record<string, PatternSet> = {
  pi: {
    error: SHARED_ERROR,
    waiting: SHARED_WAITING,
    busy: [...PI_BUSY_STRONG, ...PI_BUSY_WEAK, ...SHARED_BUSY],
    idle: PI_IDLE,
  },
  claude: {
    error: SHARED_ERROR,
    waiting: SHARED_WAITING,
    busy: [...CLAUDE_BUSY, ...SHARED_BUSY],
    idle: CLAUDE_IDLE,
  },
  amp: {
    error: SHARED_ERROR,
    waiting: SHARED_WAITING,
    busy: [...AMP_BUSY, ...SHARED_BUSY],
    idle: AMP_IDLE,
  },
  opencode: {
    error: SHARED_ERROR,
    waiting: SHARED_WAITING,
    busy: [...OPENCODE_BUSY, ...SHARED_BUSY],
    idle: OPENCODE_IDLE,
  },
};

/** Fallback patterns for agents without specific tuning */
const DEFAULT_PATTERNS: PatternSet = {
  error: SHARED_ERROR,
  waiting: SHARED_WAITING,
  busy: [
    ...SHARED_BUSY,
    ...PI_BUSY_STRONG,
    ...PI_BUSY_WEAK,
    ...CLAUDE_BUSY,
    ...AMP_BUSY,
    ...OPENCODE_BUSY,
  ],
  idle: [
    ...PI_IDLE,
    ...CLAUDE_IDLE,
    ...AMP_IDLE,
    ...OPENCODE_IDLE,
    /Done\.\s*$/im,
    /completed successfully/i,
    /Session went idle/i,
    /Finished\s*$/im,
    /│\s*$/m,
    /❯\s*$/m,
  ],
};

function matchesAny(content: string, patterns: RegExp[]): boolean {
  return patterns.some((p) => p.test(content));
}

/**
 * Detect agent status from captured pane content.
 * @param content - raw pane text (will be ANSI-stripped)
 * @param agent - optional agent name for agent-specific patterns
 */
export function detectStatus(content: string, agent?: string): StatusIcon {
  if (!content?.trim()) return ICON_UNKNOWN;

  const clean = stripAnsi(content);
  const patterns = (agent && AGENT_PATTERNS[agent]) || DEFAULT_PATTERNS;

  if (matchesAny(clean, patterns.error)) return ICON_ERROR;
  if (matchesAny(clean, patterns.waiting)) return ICON_WAITING;

  // pi can retain "... (N earlier lines, ctrl+o to expand)" in recent scrollback
  // after going idle. Treat footer idle signals as stronger than weak busy hints.
  if (agent === "pi") {
    const hasStrongBusy = matchesAny(clean, [...PI_BUSY_STRONG, ...SHARED_BUSY]);
    const hasWeakBusy = matchesAny(clean, PI_BUSY_WEAK);
    const hasIdle = matchesAny(clean, PI_IDLE);

    if (hasStrongBusy) return ICON_BUSY;
    if (hasIdle) return ICON_IDLE;
    if (hasWeakBusy) return ICON_BUSY;
    return ICON_UNKNOWN;
  }

  if (matchesAny(clean, patterns.busy)) return ICON_BUSY;
  if (matchesAny(clean, patterns.idle)) return ICON_IDLE;

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
