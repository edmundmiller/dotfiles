/**
 * Process tree inspection for detecting programs in tmux panes.
 *
 * Uses a single `ps` call cached per rename cycle to avoid per-pane fork overhead.
 */
import { execFileSync } from "node:child_process";
import { basename } from "node:path";

export const SHELLS = ["bash", "zsh", "sh", "fish"];
export const WRAPPERS = ["node", "python3", "python", "ruby", "bun"];

/**
 * Known AI coding agents that run in terminals.
 * When adding a new agent, also add to AGENT_ALIASES if it has alternate binary names,
 * and to DIR_PROGRAMS if it should show the working directory in the window name.
 */
export const AGENT_PROGRAMS = [
  // Anthropic
  "claude", // Claude Code CLI

  // OpenAI
  "codex", // OpenAI Codex CLI

  // Google
  "gemini", // Gemini CLI

  // Amp
  "amp",

  // OpenCode
  "opencode",

  // pi
  "pi",

  // Aider
  "aider",

  // Goose (Block)
  "goose",

  // Mentat (AbanteAI)
  "mentat",

  // Cline (terminal mode)
  "cline",

  // Cursor (terminal agent)
  "cursor",

  // Zed AI agent
  "zed",

  // Warp AI
  "warp",

  // Continue
  "continue",

  // Sweep
  "sweep",

  // GPT Engineer / gpt-pilot
  "gpt-engineer",
  "gpt-pilot",

  // Plandex
  "plandex",

  // Devon
  "devon",

  // Roo
  "roo",
];

/** Agents that should display working directory in window name */
export const DIR_PROGRAMS = ["nvim", "vim", "vi", "git", "jjui", ...AGENT_PROGRAMS];

/** Maps alternate binary names → canonical agent name */
const AGENT_ALIASES: Record<string, string> = {
  oc: "opencode",
  "codex-cli": "codex",
  "gpt-engineer": "gpt-engineer",
  "gpt-pilot": "gpt-pilot",
};

// ── Regex patterns for cmdline matching ────────────────────────────────────

const allNames = [...new Set([...AGENT_PROGRAMS, ...Object.keys(AGENT_ALIASES)])];
const sorted = allNames.sort((a, b) => b.length - a.length);
const AGENT_RE = new RegExp(`(^|[ /])(${sorted.map(escapeRegex).join("|")})(?=\\s|$|[/.:-])`, "i");

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// ── Cached process table ───────────────────────────────────────────────────

interface PsEntry {
  ppid: string;
  cmdline: string;
}

let psCache: PsEntry[] | null = null;

/** Load process table once, reuse for all panes in this cycle. */
export function loadProcessTable(): void {
  try {
    const output = execFileSync("ps", ["-a", "-oppid=,command="], {
      encoding: "utf8",
      timeout: 3000,
      stdio: ["pipe", "pipe", "ignore"],
    }).trim();

    psCache = [];
    for (const raw of output.split("\n")) {
      const line = raw.trim();
      if (!line) continue;
      const spaceIdx = line.indexOf(" ");
      if (spaceIdx < 0) continue;
      psCache.push({
        ppid: line.slice(0, spaceIdx).trim(),
        cmdline: line.slice(spaceIdx + 1).trim(),
      });
    }
  } catch {
    psCache = [];
  }
}

/** Clear cache at end of cycle. */
export function clearProcessTable(): void {
  psCache = null;
}

export function getChildCmdline(panePid: string): string {
  if (!panePid) return "";
  if (!psCache) loadProcessTable();

  for (const entry of psCache!) {
    if (entry.ppid !== panePid) continue;
    if (entry.cmdline.includes("smart-name")) continue;

    // Skip login shells (e.g. "-zsh")
    const cmd = entry.cmdline.split(/\s+/)[0];
    if (cmd.startsWith("-")) continue;

    return entry.cmdline;
  }
  return "";
}

// ── Program normalization ──────────────────────────────────────────────────

export function normalizeProgram(cmdline: string): string {
  if (!cmdline) return "";

  const agent = detectAgentFromCmdline(cmdline);
  if (agent) return agent;

  const firstToken = cmdline.trim().split(/\s+/)[0];
  if (!firstToken) return "";

  let name = basename(firstToken);
  if (name.startsWith("-")) name = name.slice(1);

  const direct = normalizeAgentName(name);
  if (direct) return direct;

  return name;
}

function normalizeAgentName(name: string): string | null {
  const lowered = name.toLowerCase();
  if (AGENT_ALIASES[lowered]) return AGENT_ALIASES[lowered];
  if (AGENT_PROGRAMS.includes(lowered)) return lowered;
  return null;
}

function detectAgentFromCmdline(cmdline: string): string | null {
  const tokens = cmdline.trim().split(/\s+/);
  for (const token of tokens) {
    if (!token || /^[A-Za-z_][A-Za-z0-9_]*=.*/.test(token)) continue;
    for (const candidate of extractCandidates(token)) {
      const normalized = normalizeAgentName(candidate);
      if (normalized) return normalized;
    }
  }

  const match = cmdline.match(AGENT_RE);
  if (match) {
    return normalizeAgentName(match[2]) ?? match[2].toLowerCase();
  }
  return null;
}

function extractCandidates(token: string): string[] {
  const cleaned = token.replace(/^['"]+|['"]+$/g, "");
  if (!cleaned) return [];

  const values = new Set<string>();

  function add(raw: string): void {
    if (!raw) return;
    let value = raw
      .replace(/^['"]+|['"]+$/g, "")
      .replace(/^[^A-Za-z0-9@]+|[^A-Za-z0-9-]+$/g, "")
      .toLowerCase();
    if (!value) return;
    if (value.startsWith("-")) value = value.slice(1);
    if (!value) return;
    values.add(value);
    values.add(value.replace(/\.(?:mjs|cjs|js|ts|jsx|tsx)$/i, ""));
  }

  add(cleaned);
  add(basename(cleaned));
  for (const segment of cleaned.split("/")) add(segment);

  return [...values].filter(Boolean);
}

export function getPaneProgram(paneCmd: string, panePid: string): string {
  if (AGENT_PROGRAMS.includes(paneCmd)) return paneCmd;
  if (AGENT_ALIASES[paneCmd]) return AGENT_ALIASES[paneCmd];

  if (panePid && (SHELLS.includes(paneCmd) || WRAPPERS.includes(paneCmd))) {
    const childCmd = getChildCmdline(panePid);
    if (childCmd) {
      return normalizeProgram(childCmd) || paneCmd;
    }
  }
  return paneCmd;
}
