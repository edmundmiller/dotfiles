/**
 * Process tree inspection for detecting programs in tmux panes.
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
  "gpt-engineer": "gpt-engineer",
  "gpt-pilot": "gpt-pilot",
};

// ── Regex patterns for cmdline matching ────────────────────────────────────
// Built dynamically from AGENT_PROGRAMS + AGENT_ALIASES

const allNames = [...new Set([...AGENT_PROGRAMS, ...Object.keys(AGENT_ALIASES)])];
// Sort longest-first so "gpt-engineer" matches before "gpt"
const sorted = allNames.sort((a, b) => b.length - a.length);
const AGENT_RE = new RegExp(`(^|[ /])(${sorted.map(escapeRegex).join("|")})(\\s|$)`);

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// ── Process helpers ────────────────────────────────────────────────────────

export function runPs(args: string[]): string {
  try {
    return execFileSync(args[0], args.slice(1), {
      encoding: "utf8",
      timeout: 3000,
      stdio: ["pipe", "pipe", "ignore"],
    }).trim();
  } catch {
    return "";
  }
}

export function getCmdlineForPid(pid: string): string {
  if (!pid) return "";
  return runPs(["ps", "-p", pid, "-o", "command="]);
}

export function getChildCmdline(panePid: string): string {
  if (!panePid) return "";
  const output = runPs(["ps", "-a", "-oppid=,command="]);
  if (!output) return "";

  for (const raw of output.split("\n")) {
    const line = raw.trim();
    if (!line) continue;
    const spaceIdx = line.indexOf(" ");
    if (spaceIdx < 0) continue;

    const ppid = line.slice(0, spaceIdx).trim();
    const cmdline = line.slice(spaceIdx + 1).trim();
    if (ppid !== panePid) continue;
    if (cmdline.includes("smart-name")) continue;

    // Skip login shells (e.g. "-zsh")
    const cmd = cmdline.split(/\s+/)[0];
    if (cmd.startsWith("-")) continue;

    return cmdline;
  }
  return "";
}

export function normalizeProgram(cmdline: string): string {
  if (!cmdline) return "";

  const match = cmdline.match(AGENT_RE);
  if (match) {
    const name = match[2];
    return AGENT_ALIASES[name] ?? name;
  }

  let name = basename(cmdline.trim().split(/\s+/)[0]);
  if (name.startsWith("-")) name = name.slice(1); // strip login shell prefix

  // Check if basename matches an alias
  if (AGENT_ALIASES[name]) return AGENT_ALIASES[name];

  return name;
}

export function getPaneProgram(paneCmd: string, panePid: string): string {
  if (AGENT_PROGRAMS.includes(paneCmd)) return paneCmd;

  // Check aliases for pane_current_command
  if (AGENT_ALIASES[paneCmd]) return AGENT_ALIASES[paneCmd];

  if (panePid && (SHELLS.includes(paneCmd) || WRAPPERS.includes(paneCmd))) {
    const childCmd = getChildCmdline(panePid);
    if (childCmd) {
      return normalizeProgram(childCmd) || paneCmd;
    }
  }
  return paneCmd;
}
