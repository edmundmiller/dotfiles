import type { Plugin, PluginInput } from "@opencode-ai/plugin";
import { execFileSync, spawn } from "child_process";
import { readFileSync, existsSync } from "fs";
import { join, basename } from "path";

const INTENTS = [
  "feat",
  "fix",
  "debug",
  "refactor",
  "test",
  "doc",
  "ops",
  "review",
  "spike",
] as const;
type Intent = (typeof INTENTS)[number];

type Status = "busy" | "idle" | "waiting" | "error" | "unknown";

const STATUS_ICONS: Record<Status, string> = {
  busy: "●",
  idle: "□",
  waiting: "■",
  error: "▲",
  unknown: "◇",
};

interface WorkmuxContext {
  branch: string;
  projectRoot: string;
  isWorktree: boolean;
}

interface PluginConfig {
  cooldownMs: number;
  debounceMs: number;
  maxSignals: number;
  debug: boolean;
  useAgentsMd: boolean;
  showStatus: boolean;
  workmuxAware: boolean;
  workmuxFormat: "project" | "branch" | "both";
}

interface State {
  lastRename: number;
  lastCheck: number;
  currentName: string;
  signals: string[];
  status: Status;
}

interface PluginEvent {
  type: string;
  path?: string;
  command?: string;
  messages?: Array<{ content?: string }>;
  todos?: Array<{ content?: string }>;
  status?: string;
}

function loadConfig(): PluginConfig {
  const env = process.env;
  return {
    cooldownMs: Number(env.OPENCODE_TMUX_COOLDOWN_MS) || 5 * 60 * 1000,
    debounceMs: Number(env.OPENCODE_TMUX_DEBOUNCE_MS) || 5 * 1000,
    maxSignals: Number(env.OPENCODE_TMUX_MAX_SIGNALS) || 25,
    debug: env.OPENCODE_TMUX_DEBUG === "1",
    useAgentsMd: env.OPENCODE_TMUX_USE_AGENTS_MD !== "0",
    showStatus: env.OPENCODE_TMUX_SHOW_STATUS !== "0",
    workmuxAware: env.OPENCODE_TMUX_WORKMUX_AWARE !== "0",
    workmuxFormat: (env.OPENCODE_TMUX_WORKMUX_FORMAT as "project" | "branch" | "both") || "both",
  };
}

function createLogger(debug: boolean) {
  return {
    debug: (msg: string) => {
      if (debug) console.log(`[tmux-namer] ${msg}`);
    },
    info: (msg: string) => console.log(`[tmux-namer] ${msg}`),
    error: (msg: string) => console.error(`[tmux-namer] ${msg}`),
  };
}

function isInTmux(): boolean {
  return !!process.env.TMUX;
}

function findTmux(log: ReturnType<typeof createLogger>): string {
  const paths = ["/usr/local/bin/tmux", "/usr/bin/tmux", "/opt/homebrew/bin/tmux"];

  for (const p of paths) {
    try {
      if (existsSync(p)) {
        execFileSync(p, ["-V"], { stdio: "ignore", timeout: 1000 });
        log.debug(`Found tmux at: ${p}`);
        return p;
      }
    } catch (e) {
      log.debug(`Tmux not at ${p}: ${e instanceof Error ? e.message : "unknown"}`);
    }
  }

  try {
    execFileSync("tmux", ["-V"], { stdio: "ignore", timeout: 1000 });
    log.debug("Using tmux from PATH");
    return "tmux";
  } catch {
    log.debug("Tmux not found in PATH");
  }

  return "tmux";
}

function sanitize(input: string, maxLen = 20): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-/, "")
    .replace(/-$/, "")
    .slice(0, maxLen);
}

/**
 * Detect if we're in a workmux-managed worktree.
 * Workmux uses bare repo layout with worktrees as siblings.
 * Pattern: project/.git (bare) + project/branch-name/ (worktrees)
 */
function getWorkmuxContext(
  cwd: string,
  log: ReturnType<typeof createLogger>
): WorkmuxContext | null {
  try {
    // Check if we're in a git worktree
    const gitDir = execFileSync("git", ["rev-parse", "--git-dir"], {
      cwd,
      encoding: "utf8",
      timeout: 2000,
      stdio: ["pipe", "pipe", "ignore"],
    }).trim();

    // Worktrees have .git files pointing to .git/worktrees/<name>
    // or gitdir paths containing /worktrees/
    if (!gitDir.includes("/worktrees/") && !gitDir.includes(".git/worktrees")) {
      log.debug("Not a worktree");
      return null;
    }

    // Get the branch name
    const branch = execFileSync("git", ["branch", "--show-current"], {
      cwd,
      encoding: "utf8",
      timeout: 2000,
      stdio: ["pipe", "pipe", "ignore"],
    }).trim();

    if (!branch) {
      log.debug("No current branch (detached HEAD?)");
      return null;
    }

    // Extract project root from gitDir path
    // gitDir format: /path/to/mainrepo/.git/worktrees/worktree-name
    // We want: /path/to/mainrepo
    const gitDirMatch = gitDir.match(/^(.+)\/\.git\/worktrees\//);
    if (!gitDirMatch) {
      log.debug("Could not parse gitDir for project root");
      return null;
    }
    const projectRoot = gitDirMatch[1];

    log.debug(`Workmux detected: branch=${branch}, root=${projectRoot}`);
    return { branch, projectRoot, isWorktree: true };
  } catch (e) {
    log.debug(`Workmux detection failed: ${e instanceof Error ? e.message : "unknown"}`);
    return null;
  }
}

function getProjectName(cwd: string, log: ReturnType<typeof createLogger>): string {
  // Try package.json
  try {
    const pkgPath = join(cwd, "package.json");
    if (existsSync(pkgPath)) {
      const pkg = JSON.parse(readFileSync(pkgPath, "utf8"));
      if (pkg.name && typeof pkg.name === "string") {
        const name = pkg.name.replace(/^@[^/]+\//, "");
        log.debug(`Project from package.json: ${name}`);
        return sanitize(name);
      }
    }
  } catch {
    log.debug("No package.json found");
  }

  // Try git repo name
  try {
    const output = execFileSync("git", ["remote", "get-url", "origin"], {
      cwd,
      encoding: "utf8",
      timeout: 2000,
      stdio: ["pipe", "pipe", "ignore"],
    });
    const match = output.match(/\/([^/]+?)(?:\.git)?$/);
    if (match) {
      log.debug(`Project from git: ${match[1]}`);
      return sanitize(match[1]);
    }
  } catch {
    log.debug("Not a git repo or no remote");
  }

  // Fall back to directory name
  const dir = basename(cwd);
  log.debug(`Project from directory: ${dir}`);
  return sanitize(dir);
}

function inferIntent(text: string): Intent {
  const t = text.toLowerCase();
  if (/\b(test|pytest|jest|spec|vitest)\b/.test(t)) return "test";
  if (/\b(debug|trace|breakpoint|stack|error)\b/.test(t)) return "debug";
  if (/\b(fix|bug|broken|issue|patch)\b/.test(t)) return "fix";
  if (/\b(refactor|cleanup|reorganize|restructure)\b/.test(t)) return "refactor";
  if (/\b(doc|readme|documentation)\b/.test(t)) return "doc";
  if (/\b(review|pr|pull.?request)\b/.test(t)) return "review";
  if (/\b(deploy|docker|k8s|terraform|ci|cd)\b/.test(t)) return "ops";
  if (/\b(spike|explore|research|investigate|poc)\b/.test(t)) return "spike";
  return "feat";
}

function inferTag(text: string): string | null {
  const t = text.toLowerCase();
  const patterns: [RegExp, string][] = [
    [/\b(auth|login|jwt|oauth|session)\b/, "auth"],
    [/\b(api|rest|graphql|endpoint)\b/, "api"],
    [/\b(db|database|sql|postgres|mysql|mongo)\b/, "db"],
    [/\b(cache|redis|memcached)\b/, "cache"],
    [/\b(ui|frontend|react|vue|svelte|css)\b/, "ui"],
    [/\b(nf|nextflow|pipeline|workflow)\b/, "nf"],
    [/\b(nix|darwin|flake)\b/, "nix"],
    [/\b(tmux|terminal|shell)\b/, "term"],
  ];

  for (const [pattern, tag] of patterns) {
    if (pattern.test(t)) return tag;
  }
  return null;
}

function buildName(
  project: string,
  intent: Intent,
  tag: string | null,
  status: Status,
  showStatus: boolean,
  workmux: WorkmuxContext | null,
  workmuxFormat: "project" | "branch" | "both"
): string {
  const statusIcon = showStatus ? `${STATUS_ICONS[status]} ` : "";

  // When in workmux worktree, use branch-focused naming
  if (workmux) {
    const branch = sanitize(workmux.branch, 25);
    const proj = sanitize(basename(workmux.projectRoot), 15);

    switch (workmuxFormat) {
      case "branch":
        // Just branch: "● fix-auth"
        return `${statusIcon}${branch}`;
      case "project":
        // Just project with intent: "● myproject-feat"
        return `${statusIcon}${proj}-${intent}`;
      case "both":
      default:
        // Branch with project context: "● fix-auth (proj)"
        if (branch.length + proj.length + 4 <= 35) {
          return `${statusIcon}${branch} (${proj})`;
        }
        return `${statusIcon}${branch}`;
    }
  }

  // Standard naming: project-intent[-tag]
  const base = `${statusIcon}${project}-${intent}`;
  if (tag && base.length + tag.length + 1 <= 40) {
    return `${base}-${tag}`;
  }
  return base;
}

function renameWindow(name: string, tmux: string, log: ReturnType<typeof createLogger>): boolean {
  try {
    spawn(tmux, ["rename-window", name], {
      detached: true,
      stdio: "ignore",
    }).unref();
    log.debug(`Renamed window to: ${name}`);
    return true;
  } catch (e) {
    log.error(`Rename failed: ${e instanceof Error ? e.message : "unknown"}`);
    return false;
  }
}

function isValidEvent(e: unknown): e is PluginEvent {
  return (
    typeof e === "object" &&
    e !== null &&
    "type" in e &&
    typeof (e as PluginEvent).type === "string"
  );
}

function addSignal(state: State, signal: string, maxSignals: number): void {
  const safe = signal.slice(0, 200);
  state.signals.push(safe);
  if (state.signals.length > maxSignals) {
    state.signals = state.signals.slice(-maxSignals);
  }
}

function mapSessionStatus(status: string): Status {
  switch (status) {
    case "running":
    case "streaming":
      return "busy";
    case "idle":
    case "completed":
      return "idle";
    case "pending":
    case "waiting":
      return "waiting";
    case "error":
    case "failed":
      return "error";
    default:
      return "unknown";
  }
}

function loadAgentsMdGuidance(
  directory: string,
  log: ReturnType<typeof createLogger>
): string | null {
  const locations = [
    join(directory, "AGENTS.md"),
    join(directory, ".github", "AGENTS.md"),
    join(directory, "docs", "AGENTS.md"),
  ];

  for (const loc of locations) {
    try {
      if (existsSync(loc)) {
        const content = readFileSync(loc, "utf8");
        log.debug(`Found AGENTS.md at: ${loc}`);
        // Extract naming section if present
        const match = content.match(/##\s*(?:Session\s*)?Naming[^\n]*\n([\s\S]*?)(?=\n##|$)/i);
        if (match) {
          return match[1].trim();
        }
      }
    } catch {
      continue;
    }
  }
  return null;
}

export const TmuxNamer: Plugin = async ({ directory }) => {
  const config = loadConfig();
  const log = createLogger(config.debug);
  const state: State = {
    lastRename: 0,
    lastCheck: 0,
    currentName: "",
    signals: [],
    status: "idle",
  };

  const tmux = findTmux(log);
  let agentsMdGuidance: string | null = null;

  // Detect workmux context once at startup
  const workmuxContext = config.workmuxAware ? getWorkmuxContext(directory, log) : null;
  if (workmuxContext) {
    log.info(`Workmux detected: branch=${workmuxContext.branch}`);
  }

  if (config.useAgentsMd) {
    agentsMdGuidance = loadAgentsMdGuidance(directory, log);
    if (agentsMdGuidance) {
      log.debug(`Loaded naming guidance from AGENTS.md`);
    }
  }

  log.debug(`Initialized with config: ${JSON.stringify(config)}`);

  if (!isInTmux()) {
    log.debug("Not in tmux session, plugin disabled");
    return { event: async () => {} };
  }

  async function maybeRename(cwd: string): Promise<void> {
    const now = Date.now();
    if (now - state.lastCheck < config.debounceMs) {
      log.debug("Skipped: debounce");
      return;
    }
    state.lastCheck = now;

    if (now - state.lastRename < config.cooldownMs) {
      log.debug("Skipped: cooldown");
      return;
    }

    const project = getProjectName(cwd, log);
    const signalText = state.signals.join(" ");
    const intent = inferIntent(signalText);
    const tag = inferTag(signalText);

    const name = buildName(
      project,
      intent,
      tag,
      state.status,
      config.showStatus,
      workmuxContext,
      config.workmuxFormat
    );

    if (name === state.currentName) {
      log.debug("Skipped: name unchanged");
      return;
    }

    if (renameWindow(name, tmux, log)) {
      state.currentName = name;
      state.lastRename = now;
      state.signals = [];
    }
  }

  function updateStatusOnly(): void {
    if (!config.showStatus || !state.currentName) return;

    // Update just the status icon in the existing name
    const project = getProjectName(directory, log);
    const signalText = state.signals.join(" ");
    const intent = inferIntent(signalText);
    const tag = inferTag(signalText);

    const newName = buildName(
      project,
      intent,
      tag,
      state.status,
      config.showStatus,
      workmuxContext,
      config.workmuxFormat
    );
    if (newName !== state.currentName) {
      if (renameWindow(newName, tmux, log)) {
        state.currentName = newName;
      }
    }
  }

  // Initial rename on plugin load
  process.nextTick(async () => {
    try {
      await maybeRename(directory);
    } catch (e) {
      log.error(`Initial rename failed: ${e instanceof Error ? e.message : "unknown"}`);
    }
  });

  return {
    event: async ({ event }: { event: unknown }) => {
      if (!isValidEvent(event)) {
        log.debug("Invalid event received");
        return;
      }

      // Handle session status changes for real-time status updates
      if (event.type === "session.status" && event.status) {
        const newStatus = mapSessionStatus(event.status);
        if (newStatus !== state.status) {
          state.status = newStatus;
          updateStatusOnly();
        }
        return;
      }

      if (event.type === "session.idle") {
        state.status = "idle";
        const msgs = event.messages || [];
        const lastMsg = msgs[msgs.length - 1];
        if (lastMsg?.content && typeof lastMsg.content === "string") {
          addSignal(state, lastMsg.content, config.maxSignals);
        }
        process.nextTick(() =>
          maybeRename(directory).catch((e) => log.error(e?.message || "unknown"))
        );
      }

      if (event.type === "file.edited" && event.path && typeof event.path === "string") {
        addSignal(state, `file:${event.path}`, config.maxSignals);
      }

      if (event.type === "command.executed" && event.command && typeof event.command === "string") {
        addSignal(state, `cmd:${event.command}`, config.maxSignals);
      }

      if (event.type === "todo.updated") {
        const todos = event.todos || [];
        const first = todos[0];
        if (first?.content && typeof first.content === "string") {
          addSignal(state, `todo:${first.content}`, config.maxSignals);
        }
      }

      if (event.type === "permission.updated" || event.type === "permission.replied") {
        state.status = "waiting";
        updateStatusOnly();
      }
    },
  };
};

export default TmuxNamer;
