#!/usr/bin/env node
/**
 * tmux-smart-name — smart window naming with AI agent status detection.
 * No external dependencies.
 */
import { hasSessions, listAllPanes, capturePane, renameWindow, type TmuxPane } from "./tmux.js";
import { AGENT_PROGRAMS, getPaneProgram, loadProcessTable, clearProcessTable } from "./process.js";
import { detectStatus, prioritize, colorize } from "./status.js";
import { formatPath, buildBaseName, trimName } from "./naming.js";
import { getAllAgentsInfo, generateMenuCommand, runMenu } from "./menu.js";

// ── Main rename ────────────────────────────────────────────────────────────

function renameAll(): void {
  if (!hasSessions()) return;

  try {
    // Single ps call for all panes
    loadProcessTable();

    // Single tmux call for all panes across all sessions
    const allPanes = listAllPanes();

    for (const [windowId, panes] of allPanes) {
      try {
        if (panes.length === 0) continue;

        const active = panes.find((p) => p.active) ?? panes[0];
        const program = getPaneProgram(active.command, active.pid);
        const path = formatPath(active.path);
        const baseName = buildBaseName(program, path);

        if (!baseName && !program) continue;

        // Check all panes for agents
        const agentPanes: Array<{ paneId: string; agent: string }> = [];
        for (const pane of panes) {
          const prog = getPaneProgram(pane.command, pane.pid);
          if (AGENT_PROGRAMS.includes(prog)) {
            agentPanes.push({ paneId: pane.paneId, agent: prog });
          }
        }

        let newName: string;
        if (agentPanes.length > 0) {
          // Capture agent panes for status detection, passing agent name for tuned patterns
          const statuses = agentPanes.map((a) => detectStatus(capturePane(a.paneId), a.agent));
          const agentStatus = prioritize(statuses);
          const icon = colorize(agentStatus);
          newName = `${icon} ${baseName}`;
        } else {
          newName = baseName;
        }

        newName = trimName(newName);
        const currentName = panes[0].windowName ?? "";

        if (currentName !== newName) {
          renameWindow(windowId, newName);
        }
      } catch {
        continue;
      }
    }
  } catch {
    // silently fail
  } finally {
    clearProcessTable();
  }
}

// ── Global status ──────────────────────────────────────────────────────────

function printGlobalStatus(): void {
  try {
    if (!hasSessions()) return;

    loadProcessTable();
    const agents = getAllAgentsInfo();
    clearProcessTable();

    if (agents.length === 0) return;

    const statuses = agents.map((a) => a.status);
    const top = prioritize(statuses);
    console.log(`${top} ${agents.length}`);
  } catch {
    // silent
  }
}

// ── Check attention ────────────────────────────────────────────────────────

import { execFileSync } from "node:child_process";

function checkAttention(): void {
  try {
    if (!hasSessions()) return;

    loadProcessTable();
    const agents = getAllAgentsInfo();
    clearProcessTable();

    const attention = agents.filter(
      (a) => a.status === "▲" || a.status === "■" || a.status === "◇"
    );

    if (attention.length > 0) {
      let lastCount = 0;
      try {
        const out = execFileSync("tmux", ["show-environment", "-g", "TMUX_AGENT_LAST_ATTENTION"], {
          encoding: "utf8",
          stdio: ["pipe", "pipe", "ignore"],
        })
          .trim()
          .split("=")[1];
        lastCount = parseInt(out, 10) || 0;
      } catch {
        // not set
      }

      if (attention.length > lastCount) {
        execFileSync("tmux", ["run-shell", "-b", "printf '\\a'"]);
        execFileSync("tmux", [
          "set-environment",
          "-g",
          "TMUX_AGENT_LAST_ATTENTION",
          String(attention.length),
        ]);
      }
    } else {
      try {
        execFileSync("tmux", ["set-environment", "-g", "TMUX_AGENT_LAST_ATTENTION", "0"]);
      } catch {
        // ignore
      }
    }
  } catch {
    // silent
  }
}

// ── CLI ────────────────────────────────────────────────────────────────────

const arg = process.argv[2];

switch (arg) {
  case "--status":
    printGlobalStatus();
    break;
  case "--menu":
    runMenu();
    break;
  case "--menu-cmd": {
    loadProcessTable();
    const cmd = generateMenuCommand(getAllAgentsInfo());
    clearProcessTable();
    console.log(cmd ?? 'display-message "No AI agents running"');
    break;
  }
  case "--check-attention":
    checkAttention();
    break;
  default:
    renameAll();
}
