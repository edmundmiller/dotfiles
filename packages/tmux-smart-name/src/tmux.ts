/**
 * Tmux subprocess helpers — zero dependencies.
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

export function capturePane(paneId: string, lines = 20): string {
  return tmuxCmd("capture-pane", "-p", "-t", paneId, "-S", `-${lines}`).join("\n");
}

export function renameWindow(windowId: string, name: string): void {
  tmuxCmd("rename-window", "-t", windowId, name);
}
