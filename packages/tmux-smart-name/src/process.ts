/**
 * Process tree inspection for detecting programs in tmux panes.
 */
import { execFileSync } from "node:child_process";
import { basename } from "node:path";

export const SHELLS = ["bash", "zsh", "sh", "fish"];
export const WRAPPERS = ["node", "python3", "python", "ruby", "bun"];
export const AGENT_PROGRAMS = ["opencode", "claude", "amp", "pi"];
export const DIR_PROGRAMS = ["nvim", "vim", "vi", "git", "jjui", "opencode", "claude", "amp", "pi"];

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

const OPENCODE_RE = /(^|[ /])(opencode|oc)(\b|$)/;
const CLAUDE_RE = /(^|[ /])claude(\b|$)/;
const PI_RE = /(^|[ /])pi(\s|$)/;
const AMP_RE = /(^|[ /])amp(\b|$)/;

export function normalizeProgram(cmdline: string): string {
  if (!cmdline) return "";
  if (OPENCODE_RE.test(cmdline)) return "opencode";
  if (CLAUDE_RE.test(cmdline)) return "claude";
  if (PI_RE.test(cmdline)) return "pi";
  if (AMP_RE.test(cmdline)) return "amp";

  let name = basename(cmdline.trim().split(/\s+/)[0]);
  if (name.startsWith("-")) name = name.slice(1); // strip login shell prefix
  return name;
}

export function getPaneProgram(paneCmd: string, panePid: string): string {
  if (AGENT_PROGRAMS.includes(paneCmd)) return paneCmd;

  if (panePid && (SHELLS.includes(paneCmd) || WRAPPERS.includes(paneCmd))) {
    const childCmd = getChildCmdline(panePid);
    if (childCmd) {
      return normalizeProgram(childCmd) || paneCmd;
    }
  }
  return paneCmd;
}
