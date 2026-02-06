/**
 * Agent management menu — generates tmux display-menu commands.
 */
import { execFileSync } from "node:child_process";
import { hasSessions, listAllPanes, capturePane, type TmuxPane } from "./tmux.js";
import { AGENT_PROGRAMS, getPaneProgram } from "./process.js";
import {
  detectStatus,
  prioritize,
  colorize,
  ICON_COLORS,
  ICON_ERROR,
  ICON_WAITING,
  ICON_UNKNOWN,
  ICON_BUSY,
  type StatusIcon,
} from "./status.js";
import { formatPath } from "./naming.js";

export interface AgentInfo {
  session: string;
  windowIndex: string;
  windowName: string;
  paneId: string;
  program: string;
  status: StatusIcon;
  path: string;
}

export function findAgentPanes(panes: TmuxPane[]): Array<{ pane: TmuxPane; program: string }> {
  const agents: Array<{ pane: TmuxPane; program: string }> = [];
  for (const pane of panes) {
    const program = getPaneProgram(pane.command, pane.pid);
    if (AGENT_PROGRAMS.includes(program)) {
      agents.push({ pane, program });
    }
  }
  return agents;
}

export function getAllAgentsInfo(): AgentInfo[] {
  const agents: AgentInfo[] = [];
  const allPanes = listAllPanes();

  for (const [, panes] of allPanes) {
    for (const { pane, program } of findAgentPanes(panes)) {
      agents.push({
        session: pane.sessionName ?? "",
        windowIndex: pane.windowIndex ?? "",
        windowName: pane.windowName ?? "",
        paneId: pane.paneId,
        program,
        status: detectStatus(capturePane(pane.paneId)),
        path: formatPath(pane.path),
      });
    }
  }
  return agents;
}

const ATTENTION = new Set<StatusIcon>([ICON_ERROR, ICON_WAITING, ICON_UNKNOWN]);
const STATUS_PRIORITY: Record<StatusIcon, number> = {
  "▲": 0,
  "◇": 1,
  "■": 2,
  "●": 3,
  "□": 4,
};

export function generateMenuCommand(agents: AgentInfo[]): string | null {
  if (agents.length === 0) return null;

  const sorted = [...agents].sort(
    (a, b) =>
      (STATUS_PRIORITY[a.status] ?? 5) - (STATUS_PRIORITY[b.status] ?? 5) ||
      a.session.localeCompare(b.session) ||
      a.windowIndex.localeCompare(b.windowIndex)
  );

  const statuses = agents.map((a) => a.status);
  const aggregate = prioritize(statuses);
  const attentionCount = statuses.filter((s) => ATTENTION.has(s)).length;

  const items: string[] = [];

  const header =
    attentionCount > 0
      ? `${aggregate} ${agents.length} agents (${attentionCount} need attention)`
      : `${aggregate} ${agents.length} agents`;

  items.push(`"${header}" "" ""`);
  items.push('"-" "" ""');

  for (let i = 0; i < sorted.length; i++) {
    const a = sorted[i];
    let path = a.path;
    if (path && path.length > 20) path = "..." + path.slice(-17);

    let label = `${a.status} ${a.program} ${a.session}:${a.windowIndex}`;
    if (path) label += ` ${path}`;

    const key = i < 9 ? String(i + 1) : "";
    const action = a.paneId
      ? `switch-client -t ${a.session}:${a.windowIndex} ; select-pane -t ${a.paneId}`
      : `switch-client -t ${a.session}:${a.windowIndex}`;

    items.push(`"${label}" "${key}" "${action}"`);
  }

  items.push('"-" "" ""');
  items.push('"Refresh" "r" "run-shell -b \\"#{TMUX_SMART_NAME_MENU_CMD}\\""');
  items.push('"Close" "q" ""');

  return `display-menu -T "Agent Management" -x C -y C ${items.join(" ")}`;
}

export function runMenu(): void {
  try {
    if (!hasSessions()) {
      execFileSync("tmux", ["display-message", "No tmux sessions"]);
      return;
    }

    const agents = getAllAgentsInfo();
    if (agents.length === 0) {
      execFileSync("tmux", ["display-message", "No AI agents running"]);
      return;
    }

    const sorted = [...agents].sort(
      (a, b) =>
        (STATUS_PRIORITY[a.status] ?? 5) - (STATUS_PRIORITY[b.status] ?? 5) ||
        a.session.localeCompare(b.session) ||
        a.windowIndex.localeCompare(b.windowIndex)
    );

    const menuArgs = ["-T", "Agent Management", "-x", "C", "-y", "C", "-C", "1"];

    const statuses = agents.map((a) => a.status);
    const aggregate = prioritize(statuses);
    const attentionCount = statuses.filter((s) => ATTENTION.has(s)).length;

    const header =
      attentionCount > 0
        ? `${colorize(aggregate)} ${agents.length} agents (${attentionCount} need attention)`
        : `${colorize(aggregate)} ${agents.length} agents`;

    menuArgs.push(header, "", "");
    menuArgs.push("", "", "");

    for (let i = 0; i < sorted.length; i++) {
      const a = sorted[i];
      let path = a.path;
      if (path && path.length > 20) path = "..." + path.slice(-17);

      let label = `${colorize(a.status)} ${a.program} ${a.session}:${a.windowIndex}`;
      if (path) label += ` ${path}`;

      const key = i < 9 ? String(i + 1) : "";
      const action = a.paneId
        ? `switch-client -t ${a.session}:${a.windowIndex} ; select-pane -t ${a.paneId}`
        : `switch-client -t ${a.session}:${a.windowIndex}`;

      menuArgs.push(label, key, action);

      if (a.paneId && a.status === ICON_BUSY) {
        menuArgs.push("  ⏹ Interrupt", "", `send-keys -t ${a.paneId} Escape`);
      }
    }

    menuArgs.push("", "", "");
    menuArgs.push("Close", "q", "");

    execFileSync("tmux", ["display-menu", ...menuArgs]);
  } catch (e) {
    try {
      execFileSync("tmux", [
        "display-message",
        `Error: ${e instanceof Error ? e.message : "unknown"}`,
      ]);
    } catch {
      // ignore
    }
  }
}
