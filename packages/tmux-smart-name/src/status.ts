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

const PI_BUSY = [
  /Working\.\.\./i, // "⠦ Working..." spinner line
  /Steering:/i, // queued steering message (agent still processing)
];

const PI_IDLE = [
  /\(anthropic\)\s+\S+/i, // pi status bar: "(anthropic) claude-opus-4-6 • medium"
  /\(openai[^)]*\)\s+\S+/i, // "(openai-codex) gpt-5.3-codex • xhigh"
  /\(google\)\s+\S+/i, // "(google) gemini-..."
  /↑\d+k?\s+↓\d+k?\s+R\d+/, // cost line: "↑343 ↓20k R11M W820k $10.960"
  /\$\d+\.\d+\s+\(sub\)/i, // "$10.960 (sub)"
  /\bLSP\b/, // LSP indicator at bottom
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
    busy: [...PI_BUSY, ...SHARED_BUSY],
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
  busy: [...SHARED_BUSY, ...PI_BUSY, ...CLAUDE_BUSY, ...AMP_BUSY, ...OPENCODE_BUSY],
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
