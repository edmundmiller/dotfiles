#!/usr/bin/env node
/**
 * tmux-smart-name — smart window naming with AI agent status detection.
 * No external dependencies.
 */
import {
  hasSessions,
  listSessions,
  listWindows,
  listPanes,
  capturePane,
  renameWindow,
} from "./tmux.js";
import { AGENT_PROGRAMS, getPaneProgram } from "./process.js";
import { detectStatus, prioritize, colorize, type StatusIcon } from "./status.js";
import { formatPath, buildBaseName, trimName } from "./naming.js";
import {
  findAgentPanes,
  getAggregateStatus,
  getAllAgentsInfo,
  generateMenuCommand,
  runMenu,
} from "./menu.js";

// ── Main rename ────────────────────────────────────────────────────────────

function renameAll(): void {
  if (!hasSessions()) return;

  try {
    for (const session of listSessions()) {
      for (const window of listWindows(session.id)) {
        try {
          const panes = listPanes(window.id);
          if (panes.length === 0) continue;

          const active = panes.find((p) => p.active) ?? panes[0];
          const program = getPaneProgram(active.command, active.pid);
          const path = formatPath(active.path);
          const baseName = buildBaseName(program, path);

          if (!baseName && !program) continue;

          const { status: agentStatus } = getAggregateStatus(panes);

          let newName: string;
          if (agentStatus) {
            const icon = colorize(agentStatus);
            newName = `${icon} ${baseName}`;
          } else {
            newName = baseName;
          }

          newName = trimName(newName);

          if (window.name !== newName) {
            renameWindow(window.id, newName);
          }
        } catch {
          continue;
        }
      }
    }
  } catch {
    // silently fail
  }
}

// ── Global status ──────────────────────────────────────────────────────────

function printGlobalStatus(): void {
  try {
    if (!hasSessions()) return;

    const agents = getAllAgentsInfo();
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

    const agents = getAllAgentsInfo();
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
    const cmd = generateMenuCommand(getAllAgentsInfo());
    console.log(cmd ?? 'display-message "No AI agents running"');
    break;
  }
  case "--check-attention":
    checkAttention();
    break;
  default:
    renameAll();
}
