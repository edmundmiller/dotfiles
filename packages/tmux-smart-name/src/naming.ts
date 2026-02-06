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

export function buildBaseName(program: string, path: string): string {
  if (!program) return path || "";
  if (SHELLS.includes(program)) return path || program;
  if (DIR_PROGRAMS.includes(program)) {
    return path ? `${program}: ${path}` : program;
  }
  return program;
}
