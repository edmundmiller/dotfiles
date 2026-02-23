/**
 * Window naming logic — builds display names from program + path.
 */
import { homedir } from "node:os";
import { SHELLS, DIR_PROGRAMS } from "./process.js";

export const MAX_NAME_LEN = 24;

export function formatPath(path: string): string {
  if (!path) return "";
  const home = homedir();
  if (home && path.startsWith(home)) {
    return "~" + path.slice(home.length);
  }
  return path;
}

/**
 * Shorten a path p10k-style: keep first char of intermediate dirs, full last component.
 * ~/src/personal/hledger → ~/s/p/hledger
 * ~/.config/dotfiles     → ~/.c/dotfiles
 * /usr/local/bin         → /u/l/bin
 */
export function shortenPath(path: string): string {
  if (!path) return "";

  let prefix = "";
  let rest = path;

  if (rest.startsWith("~/")) {
    prefix = "~/";
    rest = rest.slice(2);
  } else if (rest.startsWith("/")) {
    prefix = "/";
    rest = rest.slice(1);
  }

  const parts = rest.split("/").filter(Boolean);
  if (parts.length <= 1) return path;

  const shortened = parts.slice(0, -1).map((p) => {
    // Keep leading dot for hidden dirs: .config → .c
    if (p.startsWith(".") && p.length > 1) return "." + p[1];
    return p[0];
  });

  return prefix + [...shortened, parts[parts.length - 1]].join("/");
}

/** Visible length excluding tmux #[...] format codes */
function visibleLength(name: string): number {
  return name.replace(/#\[[^\]]*\]/g, "").length;
}

export function trimName(name: string, maxLen = MAX_NAME_LEN): string {
  if (maxLen <= 0 || visibleLength(name) <= maxLen) return name;

  // Walk the string tracking visible chars
  let visible = 0;
  let i = 0;
  const target = maxLen <= 3 ? maxLen : maxLen - 3;

  while (i < name.length && visible < target) {
    if (name[i] === "#" && name[i + 1] === "[") {
      // Skip #[...] sequence
      const end = name.indexOf("]", i + 2);
      if (end >= 0) {
        i = end + 1;
        continue;
      }
    }
    visible++;
    i++;
  }

  // Include any trailing #[...] that started before our cut
  while (i < name.length && name[i] === "#" && name[i + 1] === "[") {
    const end = name.indexOf("]", i + 2);
    if (end >= 0) {
      i = end + 1;
    } else {
      break;
    }
  }

  const trimmed = name.slice(0, i);
  return maxLen <= 3 ? trimmed : trimmed + "...";
}

export interface PaneContext {
  /** Git branch (omitted if main/master) */
  branch?: string;
  /** Pi session name */
  sessionName?: string;
}

/**
 * Extract branch and session name from pi's footer line.
 * Footer format: "~/path (branch)" or "~/path (branch) • session-name"
 */
export function parsePiFooter(content: string): PaneContext {
  const ctx: PaneContext = {};
  if (!content) return ctx;

  // Find the footer pwd line: "~/path (branch) • session-name" or "~/path (branch)"
  // It's the line before the stats line (which starts with ↑)
  const lines = content.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    // Footer pwd line has (branch) and next line starts with ↑ (stats)
    const next = lines[i + 1]?.trim() ?? "";
    if (/\(.*\)/.test(line) && /^↑/.test(next)) {
      const branchMatch = line.match(/\(([^)]+)\)/);
      if (branchMatch) {
        const branch = branchMatch[1];
        if (branch !== "main" && branch !== "master") {
          ctx.branch = branch;
        }
      }
      const sessionMatch = line.match(/•\s+(.+)$/);
      if (sessionMatch) {
        ctx.sessionName = sessionMatch[1].trim();
      }
      break;
    }
  }
  return ctx;
}

/** Map internal program identifiers to display names (nerd font icons). */
const DISPLAY_NAMES: Record<string, string> = {
  pi: "π",
  nvim: "",
  vim: "",
  vi: "",
};

export function buildBaseName(program: string, path: string, context?: PaneContext): string {
  if (!program) return path ? shortenPath(path) : "";
  if (SHELLS.includes(program)) return path ? shortenPath(path) : program;
  if (DIR_PROGRAMS.includes(program)) {
    const displayName = DISPLAY_NAMES[program];
    let name = displayName ?? program;
    const sep = displayName ? " " : ": ";
    const short = path ? shortenPath(path) : "";

    // Prefer session name > branch > path
    if (context?.sessionName) {
      name += `${sep}${context.sessionName}`;
    } else if (context?.branch) {
      name += `${sep}${short}@${context.branch}`;
    } else if (short) {
      name += `${sep}${short}`;
    }
    return name;
  }
  return program;
}
