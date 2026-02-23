#!/usr/bin/env node

// src/tmux.ts
import { execFileSync } from "node:child_process";
function tmuxCmd(...args) {
  try {
    const out = execFileSync("tmux", args, {
      encoding: "utf8",
      timeout: 5000,
      stdio: ["pipe", "pipe", "ignore"],
    });
    return out
      .split(
        `
`
      )
      .filter((l) => l.length > 0);
  } catch {
    return [];
  }
}
function hasSessions() {
  return tmuxCmd("list-sessions", "-F", "#{session_id}").length > 0;
}
function listAllPanes() {
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
  const byWindow = new Map();
  for (const line of lines) {
    const parts = line.split("\t", 9);
    if (parts.length < 9) continue;
    const pane = {
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
    const key = parts[1];
    const arr = byWindow.get(key);
    if (arr) {
      arr.push(pane);
    } else {
      byWindow.set(key, [pane]);
    }
  }
  return byWindow;
}
function capturePane(paneId, lines = 20) {
  return tmuxCmd("capture-pane", "-p", "-t", paneId, "-S", `-${lines}`).join(`
`);
}
function renameWindow(windowId, name) {
  tmuxCmd("rename-window", "-t", windowId, name);
}

// src/process.ts
import { execFileSync as execFileSync2 } from "node:child_process";
import { basename } from "node:path";
var SHELLS = ["bash", "zsh", "sh", "fish"];
var WRAPPERS = ["node", "python3", "python", "ruby", "bun"];
var AGENT_PROGRAMS = [
  "claude",
  "codex",
  "gemini",
  "amp",
  "opencode",
  "pi",
  "aider",
  "goose",
  "mentat",
  "cline",
  "cursor",
  "zed",
  "warp",
  "continue",
  "sweep",
  "gpt-engineer",
  "gpt-pilot",
  "plandex",
  "devon",
  "roo",
];
var DIR_PROGRAMS = ["nvim", "vim", "vi", "git", "jjui", ...AGENT_PROGRAMS];
var AGENT_ALIASES = {
  oc: "opencode",
  "codex-cli": "codex",
  "gpt-engineer": "gpt-engineer",
  "gpt-pilot": "gpt-pilot",
};
var allNames = [...new Set([...AGENT_PROGRAMS, ...Object.keys(AGENT_ALIASES)])];
var sorted = allNames.sort((a, b) => b.length - a.length);
var AGENT_RE = new RegExp(`(^|[ /])(${sorted.map(escapeRegex).join("|")})(?=\\s|$|[/.:-])`, "i");
function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
var psCache = null;
function loadProcessTable() {
  try {
    const output = execFileSync2("ps", ["-a", "-opid=,ppid=,command="], {
      encoding: "utf8",
      timeout: 3000,
      stdio: ["pipe", "pipe", "ignore"],
    }).trim();
    psCache = [];
    for (const raw of output.split(`
`)) {
      const parts = raw.trim().split(/\s+/);
      if (parts.length < 3) continue;
      const pid = parts[0];
      const ppid = parts[1];
      const cmdline = parts.slice(2).join(" ");
      if (!pid || !ppid) continue;
      psCache.push({ pid, ppid, cmdline });
    }
  } catch {
    psCache = [];
  }
}
function clearProcessTable() {
  psCache = null;
}
function getChildCmdline(panePid) {
  if (!panePid) return "";
  if (!psCache) loadProcessTable();
  for (const entry of psCache) {
    if (entry.ppid !== panePid) continue;
    if (entry.cmdline.includes("smart-name")) continue;
    const cmd = entry.cmdline.split(/\s+/)[0];
    if (cmd.startsWith("-")) continue;
    return entry.cmdline;
  }
  return "";
}
function getProcessCmdline(pid) {
  if (!pid) return "";
  if (!psCache) loadProcessTable();
  for (const entry of psCache) {
    if (entry.pid === pid) return entry.cmdline;
  }
  return "";
}
var EDITOR_FLAGS_WITH_ARGS = new Set([
  "-c",
  "--cmd",
  "-u",
  "-U",
  "-s",
  "-w",
  "-W",
  "-T",
  "-d",
  "--servername",
  "--server-name",
  "--listen",
  "--remote-send",
  "--remote-expr",
]);
function extractFilenameFromArgs(cmdline) {
  if (!cmdline) return "";
  const tokens = cmdline.trim().split(/\s+/).slice(1);
  let skipNext = false;
  for (const token of tokens) {
    if (skipNext) {
      skipNext = false;
      continue;
    }
    if (!token || token.startsWith("-") || token.startsWith("+")) {
      if (EDITOR_FLAGS_WITH_ARGS.has(token)) skipNext = true;
      continue;
    }
    const base = basename(token);
    if (!base || base === "." || base === "..") continue;
    return base;
  }
  return "";
}
function normalizeProgram(cmdline) {
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
function normalizeAgentName(name) {
  const lowered = name.toLowerCase();
  if (AGENT_ALIASES[lowered]) return AGENT_ALIASES[lowered];
  if (AGENT_PROGRAMS.includes(lowered)) return lowered;
  return null;
}
function detectAgentFromCmdline(cmdline) {
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
function extractCandidates(token) {
  const cleaned = token.replace(/^['"]+|['"]+$/g, "");
  if (!cleaned) return [];
  const values = new Set();
  function add(raw) {
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
function getPaneProgram(paneCmd, panePid) {
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

// src/status.ts
import { readFileSync, statSync } from "node:fs";
var ICON_IDLE = "□";
var ICON_BUSY = "●";
var ICON_WAITING = "■";
var ICON_ERROR = "▲";
var ICON_UNKNOWN = "◇";
var ICON_COLORS = {
  "□": "#[fg=blue]□#[default]",
  "●": "#[fg=cyan]●#[default]",
  "■": "#[fg=yellow]■#[default]",
  "▲": "#[fg=red]▲#[default]",
  "◇": "#[fg=magenta]◇#[default]",
};
function colorize(icon) {
  return ICON_COLORS[icon] ?? icon;
}
var ANSI_RE = /\x1b\[[0-9;]*[a-zA-Z]/g;
var OSC_RE = /\x1b\][^\x07]*\x07/g;
var DCS_RE = /\x1b[PX^_][^\x1b]*\x1b\\/g;
var CTRL_RE = /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]/g;
function stripAnsi(text) {
  return text.replace(ANSI_RE, "").replace(OSC_RE, "").replace(DCS_RE, "").replace(CTRL_RE, "");
}
var SHARED_ERROR = [
  /Traceback \(most recent call last\)/,
  /UnhandledPromiseRejection/i,
  /FATAL ERROR/i,
  /panic:/,
  /Error: .*(API|rate limit|connection|timeout)/i,
];
var SHARED_WAITING = [
  /Allow (?:once|always)\?/i,
  /Do you want to (?:run|execute|allow)/i,
  /(?:Approve|Confirm|Accept)\?.*\[Y\/n\]/i,
  /Press enter to continue/i,
  /Waiting for (?:input|approval|confirmation)/i,
  /Permission required/i,
  /(?:yes|no|skip)\s*›/i,
];
var SHARED_BUSY = [
  /[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/,
  /Thinking\.{2,}/i,
  /(?:Running|Executing|Processing)\.{2,}/i,
  /Working on/i,
  /Analyzing/i,
  /Reading (?:file|files)/i,
  /Writing (?:to|file)/i,
  /Searching/i,
  /Calling tool/i,
];
var PI_BUSY_STRONG = [
  /Working\.\.\./i,
  /to interrupt\)/i,
  /Auto-compacting\.\.\./i,
  /Retrying \(\d+\/\d+\)/i,
  /Summarizing branch\.\.\./i,
  /Steering:/i,
  /Follow-up:/i,
  /to edit all queued/i,
];
var PI_BUSY_WEAK = [/earlier lines,/i, /more lines,/i];
var PI_IDLE = [
  /\(anthropic\)\s+\S+/i,
  /\(openai[^)]*\)\s+\S+/i,
  /\(google\)\s+\S+/i,
  /↑\d+(?:\.\d+)?k?\s+↓\d+(?:\.\d+)?k?/,
  /\$\d+\.\d{3}/i,
  /\d+\.\d+%\/\d+k?\s+\(auto\)/,
  /\bLSP\b/,
  /\bMCP:/,
];
var CLAUDE_BUSY = [/⎿/, /Esc to cancel/i];
var CLAUDE_IDLE = [/>\s*$/m, /What would you like/i, /How can I help/i, /\d+% of \d+k/];
var AMP_BUSY = [/≋/, /■■■/, /esc interrupt/i, /Running tools/i];
var AMP_IDLE = [/ctrl\+p commands/i, /ctrl\+t variants/i];
var OPENCODE_BUSY = [/Tool:/i];
var OPENCODE_IDLE = [/OpenCode \d+\.\d+\.\d+/];
var CODEX_WAITING = [
  /Allow Codex to (?:apply proposed code changes|run|execute)/i,
  /patch-approval/i,
  /exec-approval/i,
];
var CODEX_BUSY = [/esc to interrupt/i, /Running (?:tools|commands?)/i];
var CODEX_IDLE = [/tab to add notes/i, /Compose new task/i, /no message yet/i];
var AGENT_PATTERNS = {
  claude: {
    error: SHARED_ERROR,
    waiting: SHARED_WAITING,
    busy: [...CLAUDE_BUSY, ...SHARED_BUSY],
    idle: CLAUDE_IDLE,
  },
  amp: {
    error: SHARED_ERROR,
    waiting: SHARED_WAITING,
    busy: [...AMP_BUSY, ...SHARED_BUSY],
    idle: AMP_IDLE,
  },
  opencode: {
    error: SHARED_ERROR,
    waiting: SHARED_WAITING,
    busy: [...OPENCODE_BUSY, ...SHARED_BUSY],
    idle: OPENCODE_IDLE,
  },
  codex: {
    error: SHARED_ERROR,
    waiting: [...CODEX_WAITING, ...SHARED_WAITING],
    busy: [...CODEX_BUSY, ...SHARED_BUSY],
    idle: CODEX_IDLE,
  },
};
var DEFAULT_PATTERNS = {
  error: SHARED_ERROR,
  waiting: SHARED_WAITING,
  busy: [
    ...SHARED_BUSY,
    ...PI_BUSY_STRONG,
    ...CLAUDE_BUSY,
    ...AMP_BUSY,
    ...OPENCODE_BUSY,
    ...CODEX_BUSY,
  ],
  idle: [
    ...PI_IDLE,
    ...CLAUDE_IDLE,
    ...AMP_IDLE,
    ...OPENCODE_IDLE,
    ...CODEX_IDLE,
    /Done\.\s*$/im,
    /completed successfully/i,
    /Session went idle/i,
    /Finished\s*$/im,
    /│\s*$/m,
    /❯\s*$/m,
  ],
};
function matchesAny(content, patterns) {
  return patterns.some((p) => p.test(content));
}
function detectStatus(content, agent) {
  if (!content?.trim()) return ICON_UNKNOWN;
  const clean = stripAnsi(content);
  const patterns = (agent && AGENT_PATTERNS[agent]) || DEFAULT_PATTERNS;
  if (matchesAny(clean, patterns.error)) return ICON_ERROR;
  if (matchesAny(clean, patterns.waiting)) return ICON_WAITING;
  if (agent === "pi") {
    const hasStrongBusy = matchesAny(clean, [...PI_BUSY_STRONG, ...SHARED_BUSY]);
    const hasWeakBusy = matchesAny(clean, PI_BUSY_WEAK);
    const hasIdle = matchesAny(clean, PI_IDLE);
    if (hasStrongBusy) return ICON_BUSY;
    if (hasIdle) return ICON_IDLE;
    if (hasWeakBusy) return ICON_BUSY;
    return ICON_UNKNOWN;
  }
  if (matchesAny(clean, patterns.busy)) return ICON_BUSY;
  if (matchesAny(clean, patterns.idle)) return ICON_IDLE;
  return ICON_UNKNOWN;
}
var PRIORITY = {
  "▲": 0,
  "■": 1,
  "●": 2,
  "◇": 3,
  "□": 4,
};
function prioritize(statuses) {
  if (statuses.length === 0) return ICON_IDLE;
  return statuses.reduce((best, s) => (PRIORITY[s] < PRIORITY[best] ? s : best));
}
var STATUS_DIR = "/tmp/pi-tmux-status";
var STATUS_FILE_MAX_AGE = 30000;
var STATUS_MAP = {
  busy: ICON_BUSY,
  idle: ICON_IDLE,
  waiting: ICON_WAITING,
};
function readPiStatusFile(paneId) {
  const safePane = paneId.replace(/[^a-zA-Z0-9_-]/g, "");
  const path = `${STATUS_DIR}/${safePane}.json`;
  try {
    const stat = statSync(path);
    if (Date.now() - stat.mtimeMs > STATUS_FILE_MAX_AGE) return null;
    const raw = readFileSync(path, "utf8");
    const data = JSON.parse(raw);
    return STATUS_MAP[data.status] ?? null;
  } catch {
    return null;
  }
}

// src/naming.ts
import { homedir } from "node:os";
var MAX_NAME_LEN = 24;
function formatPath(path) {
  if (!path) return "";
  const home = homedir();
  if (home && path.startsWith(home)) {
    return "~" + path.slice(home.length);
  }
  return path;
}
function shortenPath(path) {
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
    if (p.startsWith(".") && p.length > 1) return "." + p[1];
    return p[0];
  });
  return prefix + [...shortened, parts[parts.length - 1]].join("/");
}
function visibleLength(name) {
  return name.replace(/#\[[^\]]*\]/g, "").length;
}
function trimName(name, maxLen = MAX_NAME_LEN) {
  if (maxLen <= 0 || visibleLength(name) <= maxLen) return name;
  let visible = 0;
  let i = 0;
  const target = maxLen <= 3 ? maxLen : maxLen - 3;
  while (i < name.length && visible < target) {
    if (name[i] === "#" && name[i + 1] === "[") {
      const end = name.indexOf("]", i + 2);
      if (end >= 0) {
        i = end + 1;
        continue;
      }
    }
    visible++;
    i++;
  }
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
function parsePiFooter(content) {
  const ctx = {};
  if (!content) return ctx;
  const lines = content.split(`
`);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
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
var DISPLAY_NAMES = {
  pi: "π",
  nvim: "",
  vim: "",
  vi: "",
  git: "",
  claude: "\uDB94\uDC00",
  codex: "\uDB94\uDC00",
  opencode: "\uDB94\uDC02",
  aider: "",
  amp: "\uDB94\uDC01",
};
function buildBaseName(program, path, context) {
  if (!program) return path ? shortenPath(path) : "";
  if (SHELLS.includes(program)) return path ? shortenPath(path) : program;
  if (DIR_PROGRAMS.includes(program)) {
    const icon = DISPLAY_NAMES[program] ?? program;
    if (context?.sessionName) {
      return `${icon} ${context.sessionName}`;
    }
    if (context?.filename) {
      return `${icon} ${context.filename}`;
    }
    if (context?.branch) {
      const branch = context.branch.split("/").pop() ?? context.branch;
      return `${icon} #[dim]${branch}#[nodim]`;
    }
    return icon;
  }
  return program;
}

// src/menu.ts
import { execFileSync as execFileSync3 } from "node:child_process";
function findAgentPanes(panes) {
  const agents = [];
  for (const pane of panes) {
    const program = getPaneProgram(pane.command, pane.pid);
    if (AGENT_PROGRAMS.includes(program)) {
      agents.push({ pane, program });
    }
  }
  return agents;
}
function getAllAgentsInfo() {
  const agents = [];
  const allPanes = listAllPanes();
  for (const [, panes] of allPanes) {
    for (const { pane, program } of findAgentPanes(panes)) {
      agents.push({
        session: pane.sessionName ?? "",
        windowIndex: pane.windowIndex ?? "",
        windowName: pane.windowName ?? "",
        paneId: pane.paneId,
        program,
        status:
          program === "pi"
            ? (readPiStatusFile(pane.paneId) ?? detectStatus(capturePane(pane.paneId), program))
            : detectStatus(capturePane(pane.paneId), program),
        path: formatPath(pane.path),
      });
    }
  }
  return agents;
}
var ATTENTION = new Set([ICON_ERROR, ICON_WAITING, ICON_UNKNOWN]);
var STATUS_PRIORITY = {
  "▲": 0,
  "◇": 1,
  "■": 2,
  "●": 3,
  "□": 4,
};
function generateMenuCommand(agents) {
  if (agents.length === 0) return null;
  const sorted2 = [...agents].sort(
    (a, b) =>
      (STATUS_PRIORITY[a.status] ?? 5) - (STATUS_PRIORITY[b.status] ?? 5) ||
      a.session.localeCompare(b.session) ||
      a.windowIndex.localeCompare(b.windowIndex)
  );
  const statuses = agents.map((a) => a.status);
  const aggregate = prioritize(statuses);
  const attentionCount = statuses.filter((s) => ATTENTION.has(s)).length;
  const items = [];
  const header =
    attentionCount > 0
      ? `${aggregate} ${agents.length} agents (${attentionCount} need attention)`
      : `${aggregate} ${agents.length} agents`;
  items.push(`"${header}" "" ""`);
  items.push('"-" "" ""');
  for (let i = 0; i < sorted2.length; i++) {
    const a = sorted2[i];
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
function runMenu() {
  try {
    if (!hasSessions()) {
      execFileSync3("tmux", ["display-message", "No tmux sessions"]);
      return;
    }
    const agents = getAllAgentsInfo();
    if (agents.length === 0) {
      execFileSync3("tmux", ["display-message", "No AI agents running"]);
      return;
    }
    const sorted2 = [...agents].sort(
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
    for (let i = 0; i < sorted2.length; i++) {
      const a = sorted2[i];
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
    execFileSync3("tmux", ["display-menu", ...menuArgs]);
  } catch (e) {
    try {
      execFileSync3("tmux", [
        "display-message",
        `Error: ${e instanceof Error ? e.message : "unknown"}`,
      ]);
    } catch {}
  }
}

// src/index.ts
import { execFileSync as execFileSync4 } from "node:child_process";
function renameAll() {
  if (!hasSessions()) return;
  try {
    loadProcessTable();
    const allPanes = listAllPanes();
    for (const [windowId, panes] of allPanes) {
      try {
        if (panes.length === 0) continue;
        const active = panes.find((p) => p.active) ?? panes[0];
        const program = getPaneProgram(active.command, active.pid);
        const path = formatPath(active.path);
        const agentPanes = [];
        for (const pane of panes) {
          const prog = getPaneProgram(pane.command, pane.pid);
          if (AGENT_PROGRAMS.includes(prog)) {
            agentPanes.push({ paneId: pane.paneId, agent: prog });
          }
        }
        let context;
        const activeAgent = agentPanes.find((a) => a.paneId === active.paneId);
        let activeContent;
        if (activeAgent && activeAgent.agent === "pi") {
          activeContent = capturePane(active.paneId);
          context = parsePiFooter(activeContent);
        } else if (program === "nvim" || program === "vim" || program === "vi") {
          const cmdline = getChildCmdline(active.pid) || getProcessCmdline(active.pid);
          const filename = extractFilenameFromArgs(cmdline);
          if (filename) context = { filename };
        }
        const baseName = buildBaseName(program, path, context);
        if (!baseName && !program) continue;
        let newName;
        if (agentPanes.length > 0) {
          const statuses = agentPanes.map((a) => {
            if (a.agent === "pi") {
              const fileStatus = readPiStatusFile(a.paneId);
              if (fileStatus) return fileStatus;
            }
            const content =
              a.paneId === active.paneId && activeContent ? activeContent : capturePane(a.paneId);
            return detectStatus(content, a.agent);
          });
          const agentStatus = prioritize(statuses);
          if (agentStatus === "□") {
            newName = baseName;
          } else {
            const icon = colorize(agentStatus);
            newName = `${icon} ${baseName}`;
          }
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
  } finally {
    clearProcessTable();
  }
}
function printGlobalStatus() {
  try {
    if (!hasSessions()) return;
    loadProcessTable();
    const agents = getAllAgentsInfo();
    clearProcessTable();
    if (agents.length === 0) return;
    const statuses = agents.map((a) => a.status);
    const top = prioritize(statuses);
    console.log(`${top} ${agents.length}`);
  } catch {}
}
function checkAttention() {
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
        const out = execFileSync4("tmux", ["show-environment", "-g", "TMUX_AGENT_LAST_ATTENTION"], {
          encoding: "utf8",
          stdio: ["pipe", "pipe", "ignore"],
        })
          .trim()
          .split("=")[1];
        lastCount = parseInt(out, 10) || 0;
      } catch {}
      if (attention.length > lastCount) {
        execFileSync4("tmux", ["run-shell", "-b", "printf '\\a'"]);
        execFileSync4("tmux", [
          "set-environment",
          "-g",
          "TMUX_AGENT_LAST_ATTENTION",
          String(attention.length),
        ]);
      }
    } else {
      try {
        execFileSync4("tmux", ["set-environment", "-g", "TMUX_AGENT_LAST_ATTENTION", "0"]);
      } catch {}
    }
  } catch {}
}
var arg = process.argv[2];
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
  case "--tick":
    renameAll();
    checkAttention();
    break;
  default:
    renameAll();
}
