/**
 * Tmux subprocess helpers — zero dependencies.
 * Batched where possible to minimize fork overhead.
 */
import { execFileSync } from "node:child_process";

export function tmuxCmd(...args: string[]): string[] {
  try {
    const out = execFileSync("tmux", args, {
      encoding: "utf8",
      timeout: 5000,
      stdio: ["pipe", "pipe", "ignore"],
    });
    return out.split("\n").filter((l) => l.length > 0);
  } catch {
    return [];
  }
}

export function hasSessions(): boolean {
  return tmuxCmd("list-sessions", "-F", "#{session_id}").length > 0;
}

export interface TmuxSession {
  id: string;
  name: string;
}

export function listSessions(): TmuxSession[] {
  return tmuxCmd("list-sessions", "-F", "#{session_id}\t#{session_name}").flatMap((line) => {
    const [id, name] = line.split("\t", 2);
    return id && name ? [{ id, name }] : [];
  });
}

export interface TmuxWindow {
  id: string;
  index: string;
  name: string;
}

export function listWindows(sessionId: string): TmuxWindow[] {
  const fmt = "#{window_id}\t#{window_index}\t#{window_name}";
  return tmuxCmd("list-windows", "-t", sessionId, "-F", fmt).flatMap((line) => {
    const [id, index, name] = line.split("\t", 3);
    return id && index && name !== undefined ? [{ id, index, name }] : [];
  });
}

export interface TmuxPane {
  paneId: string;
  pid: string;
  command: string;
  path: string;
  active: boolean;
  /** Session name this pane belongs to (populated by listAllPanes) */
  sessionName?: string;
  /** Window ID this pane belongs to (populated by listAllPanes) */
  windowId?: string;
  /** Window index this pane belongs to (populated by listAllPanes) */
  windowIndex?: string;
  /** Window name this pane belongs to (populated by listAllPanes) */
  windowName?: string;
}

export function listPanes(windowId: string): TmuxPane[] {
  const fmt = [
    "#{pane_id}",
    "#{pane_pid}",
    "#{pane_current_command}",
    "#{pane_current_path}",
    "#{pane_active}",
  ].join("\t");
  return tmuxCmd("list-panes", "-t", windowId, "-F", fmt).flatMap((line) => {
    const parts = line.split("\t", 5);
    if (parts.length < 5) return [];
    return [
      {
        paneId: parts[0],
        pid: parts[1],
        command: parts[2],
        path: parts[3],
        active: parts[4] === "1",
      },
    ];
  });
}

/**
 * List ALL panes across all sessions/windows in a single tmux call.
 * Returns panes grouped by window ID.
 */
export function listAllPanes(): Map<string, TmuxPane[]> {
  const fmt = [
    "#{session_name}",
    "#{window_id}",
    "#{window_index}",
    "#{window_name}",
    "#{pane_id}",
    "#{pane_pid}",
    "#{pane_current_command}",
    "#{pane_current_path}",
    "#{pane_active}",
  ].join("\t");

  const lines = tmuxCmd("list-panes", "-a", "-F", fmt);
  const byWindow = new Map<string, TmuxPane[]>();

  for (const line of lines) {
    const parts = line.split("\t", 9);
    if (parts.length < 9) continue;

    const pane: TmuxPane = {
      sessionName: parts[0],
      windowId: parts[1],
      windowIndex: parts[2],
      windowName: parts[3],
      paneId: parts[4],
      pid: parts[5],
      command: parts[6],
      path: parts[7],
      active: parts[8] === "1",
    };

    const key = parts[1]; // windowId
    const arr = byWindow.get(key);
    if (arr) {
      arr.push(pane);
    } else {
      byWindow.set(key, [pane]);
    }
  }
  return byWindow;
}

export function capturePane(paneId: string, lines = 20): string {
  return tmuxCmd("capture-pane", "-p", "-t", paneId, "-S", `-${lines}`).join("\n");
}

/**
 * Capture multiple panes in a single tmux invocation.
 * Uses semicolon-separated commands to batch capture-pane calls.
 */
export function capturePanes(paneIds: string[], lines = 20): Map<string, string> {
  const results = new Map<string, string>();
  if (paneIds.length === 0) return results;

  // tmux doesn't support batching capture-pane natively,
  // but we can reduce overhead by running them in quick succession
  // For now, still individual calls but grouped — the real win is batching ps
  for (const id of paneIds) {
    results.set(id, capturePane(id, lines));
  }
  return results;
}

export function renameWindow(windowId: string, name: string): void {
  tmuxCmd("rename-window", "-t", windowId, name);
}

/**
 * Store a plain (color-code-stripped) window name as the @smart_name_plain
 * user option so set-titles-string can use it without leaking #[...] codes
 * into the terminal title bar.
 */
export function setWindowPlainName(windowId: string, plainName: string): void {
  tmuxCmd("set-option", "-wt", windowId, "@smart_name_plain", plainName);
}
