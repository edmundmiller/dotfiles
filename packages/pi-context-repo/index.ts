/**
 * Context Repository Extension
 *
 * Git-backed persistent memory filesystem for pi agents, inspired by
 * Letta Code's "Context Repositories" concept.
 *
 * Memory is stored as markdown files with YAML frontmatter in a git repo.
 * Files in `system/` are always loaded into the system prompt.
 * The full file tree is always visible so the agent can `read` any file on demand.
 *
 * Features (from Letta's design):
 * - Files as memory units with frontmatter (description, limit, read_only)
 * - `system/` subdir pinned to system prompt (always-loaded context)
 * - Progressive disclosure via file tree (agent reads what it needs)
 * - Git versioning with informative commits
 * - Pre-commit hook validates frontmatter (description required, limit positive int,
 *   read_only protected — agent can't add/remove/change it)
 * - Character limit enforcement in memory_write
 * - Backup/restore with timestamped snapshots
 * - Periodic memory reflection reminders (every N turns)
 */

import {
  chmodSync,
  cpSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { join, relative } from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import type { Dirent } from "node:fs";

// --- Helpers ---

/** Shorthand for tool results (satisfies AgentToolResult<unknown>) */
function toolResult(text: string) {
  return { content: [{ type: "text" as const, text }], details: undefined };
}

// --- Constants ---

const MEMORY_DIR_NAME = ".pi/memory";
const SYSTEM_DIR = "system";
const EXT_TYPE = "context-repo";
const ALLOWED_FM_KEYS = new Set(["description", "limit", "read_only"]);
const DEFAULT_REFLECTION_INTERVAL = 15; // turns between reflection reminders

// --- Frontmatter helpers ---

export interface Frontmatter {
  description?: string;
  limit?: number;
  read_only?: boolean;
  [key: string]: unknown;
}

export function parseFrontmatter(content: string): { frontmatter: Frontmatter; body: string } {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match?.[1] || !match[2]) return { frontmatter: {}, body: content };

  const fm: Frontmatter = {};
  for (const line of match[1].split("\n")) {
    const i = line.indexOf(":");
    if (i <= 0) continue;
    const key = line.slice(0, i).trim();
    const val = line.slice(i + 1).trim();
    if (key === "limit") fm.limit = parseInt(val, 10);
    else if (key === "read_only") fm.read_only = val === "true";
    else fm[key] = val;
  }
  return { frontmatter: fm, body: match[2].trimStart() };
}

export function buildFrontmatter(fm: Frontmatter): string {
  const lines: string[] = ["---"];
  if (fm.description) lines.push(`description: ${fm.description}`);
  if (fm.limit) lines.push(`limit: ${fm.limit}`);
  if (fm.read_only) lines.push(`read_only: true`);
  lines.push("---");
  return lines.join("\n");
}

/**
 * Validate frontmatter for a memory file. Returns array of error strings.
 * Mirrors Letta's pre-commit hook validation logic.
 */
export function validateFrontmatter(
  content: string,
  filePath: string,
  existingContent?: string | undefined
): string[] {
  const errors: string[] = [];
  const { frontmatter } = parseFrontmatter(content);

  // Frontmatter required
  if (!content.startsWith("---\n")) {
    errors.push(`${filePath}: missing frontmatter (must start with ---)`);
    return errors;
  }

  // Check closing ---
  const rest = content.slice(4);
  if (!rest.includes("\n---\n")) {
    errors.push(`${filePath}: frontmatter opened but never closed`);
    return errors;
  }

  // Extract raw frontmatter keys for unknown key check
  const fmBlock = content.slice(4, content.indexOf("\n---\n", 4));
  for (const line of fmBlock.split("\n")) {
    const i = line.indexOf(":");
    if (i <= 0) continue;
    const key = line.slice(0, i).trim();
    if (!ALLOWED_FM_KEYS.has(key)) {
      errors.push(
        `${filePath}: unknown frontmatter key '${key}' (allowed: description, limit, read_only)`
      );
    }
  }

  // Required fields
  if (!frontmatter.description) {
    errors.push(`${filePath}: missing required field 'description'`);
  }
  if (frontmatter.limit === undefined || frontmatter.limit === null) {
    errors.push(`${filePath}: missing required field 'limit'`);
  } else if (!Number.isInteger(frontmatter.limit) || frontmatter.limit <= 0) {
    errors.push(`${filePath}: 'limit' must be a positive integer, got '${frontmatter.limit}'`);
  }

  // Protected field: read_only
  if (existingContent) {
    const existing = parseFrontmatter(existingContent);

    // If file was read_only, reject any modification
    if (existing.frontmatter.read_only) {
      errors.push(`${filePath}: file is read_only and cannot be modified`);
      return errors;
    }

    // Agent can't change read_only value
    if (frontmatter.read_only !== existing.frontmatter.read_only) {
      errors.push(`${filePath}: 'read_only' is a protected field and cannot be changed`);
    }
  } else {
    // New file — agent can't set read_only
    if (frontmatter.read_only) {
      errors.push(`${filePath}: 'read_only' is a protected field and cannot be set by the agent`);
    }
  }

  return errors;
}

// --- Pre-commit hook (adapted from Letta's PRE_COMMIT_HOOK_SCRIPT) ---

const PRE_COMMIT_HOOK_SCRIPT = `#!/usr/bin/env bash
# Validate frontmatter in staged memory .md files
# Installed by pi context-repo extension

AGENT_EDITABLE_KEYS="description limit"
PROTECTED_KEYS="read_only"
ALL_KNOWN_KEYS="description limit read_only"
errors=""

get_fm_value() {
  local content="$1" key="$2"
  local closing_line
  closing_line=$(echo "$content" | tail -n +2 | grep -n '^---$' | head -1 | cut -d: -f1)
  [ -z "$closing_line" ] && return
  echo "$content" | tail -n +2 | head -n $((closing_line - 1)) | grep "^$key:" | cut -d: -f2- | sed 's/^ *//;s/ *$//'
}

for file in $(git diff --cached --name-only --diff-filter=ACM | grep '\\.md$'); do
  staged=$(git show ":$file")

  first_line=$(echo "$staged" | head -1)
  if [ "$first_line" != "---" ]; then
    errors="$errors\\n  $file: missing frontmatter (must start with ---)"
    continue
  fi

  closing_line=$(echo "$staged" | tail -n +2 | grep -n '^---$' | head -1 | cut -d: -f1)
  if [ -z "$closing_line" ]; then
    errors="$errors\\n  $file: frontmatter opened but never closed (missing closing ---)"
    continue
  fi

  head_content=$(git show "HEAD:$file" 2>/dev/null || true)
  if [ -n "$head_content" ]; then
    head_ro=$(get_fm_value "$head_content" "read_only")
    if [ "$head_ro" = "true" ]; then
      errors="$errors\\n  $file: file is read_only and cannot be modified"
      continue
    fi
  fi

  frontmatter=$(echo "$staged" | tail -n +2 | head -n $((closing_line - 1)))

  has_description=false
  has_limit=false

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    key=$(echo "$line" | cut -d: -f1 | tr -d ' ')
    value=$(echo "$line" | cut -d: -f2- | sed 's/^ *//;s/ *$//')

    known=false
    for k in $ALL_KNOWN_KEYS; do
      if [ "$key" = "$k" ]; then known=true; break; fi
    done
    if [ "$known" = "false" ]; then
      errors="$errors\\n  $file: unknown frontmatter key '$key' (allowed: $ALL_KNOWN_KEYS)"
      continue
    fi

    for k in $PROTECTED_KEYS; do
      if [ "$key" = "$k" ]; then
        if [ -n "$head_content" ]; then
          head_val=$(get_fm_value "$head_content" "$k")
          if [ "$value" != "$head_val" ]; then
            errors="$errors\\n  $file: '$k' is a protected field and cannot be changed by the agent"
          fi
        else
          errors="$errors\\n  $file: '$k' is a protected field and cannot be set by the agent"
        fi
      fi
    done

    case "$key" in
      limit)
        has_limit=true
        if ! echo "$value" | grep -qE '^[0-9]+$' || [ "$value" = "0" ]; then
          errors="$errors\\n  $file: 'limit' must be a positive integer, got '$value'"
        fi
        ;;
      description)
        has_description=true
        if [ -z "$value" ]; then
          errors="$errors\\n  $file: 'description' must not be empty"
        fi
        ;;
    esac
  done <<< "$frontmatter"

  if [ "$has_description" = "false" ]; then
    errors="$errors\\n  $file: missing required field 'description'"
  fi
  if [ "$has_limit" = "false" ]; then
    errors="$errors\\n  $file: missing required field 'limit'"
  fi

  if [ -n "$head_content" ]; then
    for k in $PROTECTED_KEYS; do
      head_val=$(get_fm_value "$head_content" "$k")
      if [ -n "$head_val" ]; then
        staged_val=$(get_fm_value "$staged" "$k")
        if [ -z "$staged_val" ]; then
          errors="$errors\\n  $file: '$k' is a protected field and cannot be removed by the agent"
        fi
      fi
    done
  fi
done

if [ -n "$errors" ]; then
  echo "Frontmatter validation failed:"
  echo -e "$errors"
  exit 1
fi
`;

export function installPreCommitHook(memDir: string): void {
  const hooksDir = join(memDir, ".git", "hooks");
  const hookPath = join(hooksDir, "pre-commit");
  mkdirSync(hooksDir, { recursive: true });
  writeFileSync(hookPath, PRE_COMMIT_HOOK_SCRIPT, "utf-8");
  chmodSync(hookPath, 0o755);
}

// --- File tree ---

export function buildTree(dir: string, prefix = ""): string[] {
  const lines: string[] = [];
  if (!existsSync(dir)) return lines;

  const entries = readdirSync(dir, { withFileTypes: true })
    .filter((e: Dirent) => !e.name.startsWith("."))
    .sort((a: Dirent, b: Dirent) => {
      if (a.isDirectory() && !b.isDirectory()) return -1;
      if (!a.isDirectory() && b.isDirectory()) return 1;
      return a.name.localeCompare(b.name);
    });

  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    const isLast = i === entries.length - 1;
    const connector = isLast ? "└── " : "├── ";
    const childPrefix = isLast ? "    " : "│   ";
    const fullPath = join(dir, entry.name);

    if (entry.isDirectory()) {
      lines.push(`${prefix}${connector}${entry.name}/`);
      lines.push(...buildTree(fullPath, prefix + childPrefix));
    } else if (entry.name.endsWith(".md")) {
      const content = readFileSync(fullPath, "utf-8");
      const { frontmatter } = parseFrontmatter(content);
      const desc = frontmatter.description ? ` — ${frontmatter.description}` : "";
      const ro = frontmatter.read_only ? " [read-only]" : "";
      lines.push(`${prefix}${connector}${entry.name}${desc}${ro}`);
    }
  }
  return lines;
}

// --- Load system/ files (recursive) ---

export function loadSystemFiles(memDir: string, dir?: string): string {
  const targetDir = dir || join(memDir, SYSTEM_DIR);
  if (!existsSync(targetDir)) return "";

  const entries = readdirSync(targetDir, { withFileTypes: true }).sort((a: Dirent, b: Dirent) => {
    if (a.isDirectory() && !b.isDirectory()) return -1;
    if (!a.isDirectory() && b.isDirectory()) return 1;
    return a.name.localeCompare(b.name);
  });

  const sections: string[] = [];
  for (const entry of entries) {
    const fullPath = join(targetDir, entry.name);
    const relPath = relative(memDir, fullPath);

    if (entry.isDirectory()) {
      const sub = loadSystemFiles(memDir, fullPath);
      if (sub) sections.push(sub);
    } else if (entry.name.endsWith(".md")) {
      const content = readFileSync(fullPath, "utf-8");
      const { body } = parseFrontmatter(content);
      if (body.trim()) {
        sections.push(`<${relPath}>\n${body.trim()}\n</${relPath}>`);
      }
    }
  }
  return sections.join("\n\n");
}

// --- Git helpers ---

async function git(
  pi: ExtensionAPI,
  cwd: string,
  args: string[]
): Promise<{ stdout: string; stderr: string }> {
  return pi.exec("git", ["-C", cwd, ...args]);
}

async function isGitRepo(pi: ExtensionAPI, dir: string): Promise<boolean> {
  try {
    await git(pi, dir, ["rev-parse", "--git-dir"]);
    return true;
  } catch {
    return false;
  }
}

async function initRepo(pi: ExtensionAPI, dir: string): Promise<void> {
  await git(pi, dir, ["init"]);
  await git(pi, dir, ["add", "."]);
  await git(pi, dir, ["commit", "-m", "init: context repository"]);
  installPreCommitHook(dir);
}

async function hasRemote(pi: ExtensionAPI, dir: string): Promise<boolean> {
  try {
    const { stdout } = await git(pi, dir, ["remote"]);
    return stdout.trim().length > 0;
  } catch {
    return false;
  }
}

async function getAheadCount(pi: ExtensionAPI, dir: string): Promise<number> {
  try {
    const { stdout } = await git(pi, dir, ["rev-list", "--count", "@{u}..HEAD"]);
    return parseInt(stdout.trim(), 10) || 0;
  } catch {
    return 0; // no upstream configured
  }
}

export interface MemoryStatus {
  dirty: boolean;
  files: string[];
  aheadOfRemote: boolean;
  aheadCount: number;
  hasRemote: boolean;
  summary: string;
}

async function getStatus(pi: ExtensionAPI, dir: string): Promise<MemoryStatus> {
  const { stdout } = await git(pi, dir, ["status", "--porcelain"]);
  const files = stdout
    .trim()
    .split("\n")
    .filter((l) => l.trim());
  const dirty = files.length > 0;

  const remote = await hasRemote(pi, dir);
  let aheadCount = 0;
  let aheadOfRemote = false;
  if (remote) {
    aheadCount = await getAheadCount(pi, dir);
    aheadOfRemote = aheadCount > 0;
  }

  const parts: string[] = [];
  if (dirty) parts.push(`${files.length} uncommitted change(s)`);
  if (aheadOfRemote) parts.push(`${aheadCount} unpushed commit(s)`);

  return {
    dirty,
    files,
    aheadOfRemote,
    aheadCount,
    hasRemote: remote,
    summary: parts.length > 0 ? parts.join(", ") : "clean",
  };
}

export function statusWidget(status: MemoryStatus): string[] {
  const parts: string[] = [];
  if (status.dirty) parts.push(`${status.files.length} uncommitted`);
  if (status.aheadOfRemote) parts.push(`${status.aheadCount} unpushed`);
  return [`Memory: ${parts.length > 0 ? parts.join(", ") : "clean"}`];
}

async function pullFromRemote(
  pi: ExtensionAPI,
  dir: string
): Promise<{ updated: boolean; summary: string }> {
  try {
    const { stdout, stderr } = await git(pi, dir, ["pull", "--ff-only"]);
    const output = stdout + stderr;
    const updated = !output.includes("Already up to date");
    return { updated, summary: updated ? output.trim() : "Already up to date" };
  } catch {
    // ff-only failed (diverged), try rebase
    try {
      const { stdout, stderr } = await git(pi, dir, ["pull", "--rebase"]);
      return { updated: true, summary: (stdout + stderr).trim() };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { updated: false, summary: `Pull failed: ${msg}` };
    }
  }
}

// --- Backup helpers (adapted from Letta's memfs.ts) ---

export function formatBackupTimestamp(date = new Date()): string {
  const pad = (v: number) => String(v).padStart(2, "0");
  return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}-${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`;
}

function getBackupDir(memDir: string): string {
  return join(memDir, "..", "memory-backups");
}

function listBackups(memDir: string): Array<{ name: string; path: string; createdAt: string }> {
  const backupRoot = getBackupDir(memDir);
  if (!existsSync(backupRoot)) return [];

  return readdirSync(backupRoot, { withFileTypes: true })
    .filter((e) => e.isDirectory() && e.name.startsWith("backup-"))
    .map((e) => {
      const path = join(backupRoot, e.name);
      const stat = statSync(path);
      return { name: e.name, path, createdAt: stat.mtime.toISOString() };
    })
    .sort((a, b) => a.name.localeCompare(b.name));
}

// --- Reflection reminder text (adapted from Letta's prompts) ---

const MEMORY_REFLECTION_REMINDER = `<system-reminder>
MEMORY REFLECTION: It's time to reflect on the recent conversation and update your memory.

Review this conversation for information worth storing. Update memory silently if you learned:

- **User info**: Name, role, preferences, working style, current goals
- **Project details**: Architecture, patterns, gotchas, dependencies, conventions
- **Corrections**: User corrected you or clarified something important
- **Preferences**: How they want you to behave, communicate, or approach tasks

Ask yourself: "If I started a new session tomorrow, what from this conversation would I want to remember?"

If the answer is meaningful, use memory_write to update the appropriate file(s), then memory_commit.
</system-reminder>`;

// --- /remember prompt ---

const REMEMBER_PROMPT = `<system-reminder>
The user has invoked /remember, requesting you commit something to memory.

## What to do

1. **Identify what to remember**: Look at recent conversation context. If they provided text after /remember, that's the target. Otherwise infer from context.

2. **Determine the right memory file**: Use memory_write to store in the appropriate file. Consider:
   - User preferences → system/user.md
   - Coding style → system/style.md
   - Project knowledge → system/project.md
   - Agent behavior → system/persona.md
   - Create a new file if no existing file fits

3. **Confirm the update**: After writing, briefly confirm what you remembered and where.

## Guidelines
- Be concise — distill to essence
- Avoid duplicates — check existing content first
- Match existing file formatting
- If unclear, ask the user to clarify
</system-reminder>`;

// --- Worktree helpers ---

export function getWorktreeDir(memDir: string): string {
  return join(memDir, "..", "memory-worktrees");
}

export interface WorktreeInfo {
  branch: string;
  path: string;
}

/**
 * Create a git worktree for isolated memory edits.
 * Returns the worktree path and branch name.
 */
export async function createWorktree(
  pi: ExtensionAPI,
  memDir: string,
  prefix: string
): Promise<WorktreeInfo> {
  const worktreeDir = getWorktreeDir(memDir);
  mkdirSync(worktreeDir, { recursive: true });

  const branch = `${prefix}-${Date.now()}`;
  const wtPath = join(worktreeDir, branch);

  await git(pi, memDir, ["worktree", "add", wtPath, "-b", branch]);

  return { branch, path: wtPath };
}

/**
 * Merge a worktree branch back to main, then clean up.
 */
export async function mergeWorktree(
  pi: ExtensionAPI,
  memDir: string,
  wt: WorktreeInfo
): Promise<{ merged: boolean; pushed: boolean; summary: string }> {
  // Pull latest first
  if (await hasRemote(pi, memDir)) {
    try {
      await git(pi, memDir, ["pull", "--ff-only"]);
    } catch {
      try {
        await git(pi, memDir, ["pull", "--rebase"]);
      } catch {
        // continue — merge may still work
      }
    }
  }

  // Merge the branch
  let merged = false;
  try {
    await git(pi, memDir, ["merge", wt.branch, "--no-edit"]);
    merged = true;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { merged: false, pushed: false, summary: `Merge failed: ${msg}` };
  }

  // Push if remote configured
  let pushed = false;
  if (await hasRemote(pi, memDir)) {
    try {
      await git(pi, memDir, ["push"]);
      pushed = true;
    } catch {
      // non-fatal — local main has the merge
    }
  }

  // Clean up worktree and branch
  try {
    await git(pi, memDir, ["worktree", "remove", wt.path]);
    await git(pi, memDir, ["branch", "-d", wt.branch]);
  } catch {
    // non-fatal
  }

  const summary = pushed ? "Merged and pushed" : "Merged (push pending)";
  return { merged, pushed, summary };
}

// --- Prompt drift detection ---

export type DriftCode =
  | "legacy_memory_section"
  | "orphan_memory_fragment"
  | "duplicate_memory_section";

export interface PromptDrift {
  code: DriftCode;
  message: string;
}

/**
 * Detect memory-related drift in system prompt.
 * Identifies legacy sections, orphan fragments, and duplicates.
 */
export function detectPromptDrift(systemPrompt: string): PromptDrift[] {
  const drifts: PromptDrift[] = [];

  // Check for legacy "Memory" sections that aren't from context-repo
  const hasLegacyMemory =
    systemPrompt.includes("Your memory consists of core memory") ||
    systemPrompt.includes("composed of memory blocks");
  if (hasLegacyMemory) {
    drifts.push({
      code: "legacy_memory_section",
      message:
        "System prompt contains legacy memory-block language incompatible with context-repo.",
    });
  }

  // Check for orphan git sync fragments without full memory section
  const hasOrphanSync =
    systemPrompt.includes("git add system/") &&
    systemPrompt.includes('git commit -m "') &&
    !systemPrompt.includes("Context Repository (Agent Memory)");
  if (hasOrphanSync) {
    drifts.push({
      code: "orphan_memory_fragment",
      message:
        "System prompt contains orphaned memory sync fragment without full context-repo section.",
    });
  }

  // Check for duplicate context-repo sections
  const contextRepoMatches = systemPrompt.match(/## Context Repository \(Agent Memory\)/g);
  if (contextRepoMatches && contextRepoMatches.length > 1) {
    drifts.push({
      code: "duplicate_memory_section",
      message: `System prompt contains ${contextRepoMatches.length} duplicate Context Repository sections.`,
    });
  }

  return drifts;
}

/**
 * Strip managed memory sections from a system prompt.
 * Used before re-injecting to prevent duplicates.
 */
export function stripManagedMemorySections(systemPrompt: string): string {
  // Remove context-repo section (## Context Repository ... to next ## or end)
  let result = systemPrompt.replace(
    /\n## Context Repository \(Agent Memory\)[\s\S]*?(?=\n## [^C]|\n## $|$)/g,
    ""
  );

  // Remove system-reminder blocks injected by this extension
  result = result.replace(
    /<system-reminder>\nMEMORY (?:SYNC|REFLECTION|CHECK):[\s\S]*?<\/system-reminder>/g,
    ""
  );

  // Compact blank lines
  result = result.replace(/\n{3,}/g, "\n\n").trimEnd();

  return result;
}

// --- Per-agent settings ---

export interface AgentSettings {
  memfsEnabled: boolean;
  reflectionInterval: number;
  personaPreset: string;
}

const DEFAULT_SETTINGS: AgentSettings = {
  memfsEnabled: true,
  reflectionInterval: DEFAULT_REFLECTION_INTERVAL,
  personaPreset: "default",
};

export function loadSettings(memDir: string): AgentSettings {
  const settingsPath = join(memDir, ".settings.json");
  if (!existsSync(settingsPath)) return { ...DEFAULT_SETTINGS };
  try {
    const raw = JSON.parse(readFileSync(settingsPath, "utf-8"));
    return { ...DEFAULT_SETTINGS, ...raw };
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}

export function saveSettings(memDir: string, settings: Partial<AgentSettings>): AgentSettings {
  const current = loadSettings(memDir);
  const merged = { ...current, ...settings };
  const settingsPath = join(memDir, ".settings.json");
  writeFileSync(settingsPath, JSON.stringify(merged, null, 2) + "\n");
  return merged;
}

// --- Persona presets (inspired by Letta's persona_claude/kawaii/memo.mdx) ---

export const PERSONA_PRESETS: Record<string, { description: string; content: string }> = {
  default: {
    description: "Agent identity and behavior guidelines",
    content: "You are a helpful coding assistant.\n",
  },
  concise: {
    description: "Agent identity — terse, direct style",
    content: `You are a terse coding assistant. Be extremely concise.
Sacrifice grammar for brevity. No filler words. Code speaks louder than prose.
When explaining, use bullets not paragraphs. Skip pleasantries.
`,
  },
  friendly: {
    description: "Agent identity — warm, collaborative style",
    content: `You are a friendly, collaborative coding assistant.
Explain your reasoning as you go. Use encouraging language.
Celebrate small wins. Ask clarifying questions when unsure.
Make the developer feel supported and productive.
`,
  },
  mentor: {
    description: "Agent identity — teaching-focused style",
    content: `You are a patient coding mentor. When solving problems:
- Explain the "why" behind decisions, not just the "what"
- Point out patterns and principles the developer can reuse
- Suggest further reading when relevant
- Ask the developer to predict outcomes before revealing answers
`,
  },
};

// --- Scaffold ---

export function scaffoldMemory(memDir: string, personaPreset?: string): void {
  const sysDir = join(memDir, SYSTEM_DIR);
  mkdirSync(sysDir, { recursive: true });

  const persona = PERSONA_PRESETS[personaPreset || "default"] || PERSONA_PRESETS.default;

  const personaFile = join(sysDir, "persona.md");
  if (!existsSync(personaFile)) {
    writeFileSync(
      personaFile,
      `${buildFrontmatter({ description: persona.description, limit: 3000 })}\n\n${persona.content}`
    );
  }

  const userFile = join(sysDir, "user.md");
  if (!existsSync(userFile)) {
    writeFileSync(
      userFile,
      `${buildFrontmatter({ description: "User preferences and context", limit: 3000 })}

(No user preferences recorded yet.)
`
    );
  }

  // Project block — codebase knowledge (inspired by Letta's project.mdx)
  const projectFile = join(sysDir, "project.md");
  if (!existsSync(projectFile)) {
    writeFileSync(
      projectFile,
      `${buildFrontmatter({ description: "Codebase architecture, patterns, gotchas, and tribal knowledge", limit: 3000 })}

I'm still getting to know this codebase.

As I work here, I'll build up knowledge about: how the code is structured and why,
patterns and conventions the team follows, footguns to avoid, tooling and workflows.

If there's an AGENTS.md, CLAUDE.md, or README, I should read it early.
`
    );
  }

  // Style block — coding preferences (inspired by Letta's style.mdx)
  const styleFile = join(sysDir, "style.md");
  if (!existsSync(styleFile)) {
    writeFileSync(
      styleFile,
      `${buildFrontmatter({ description: "User's coding preferences and conventions", limit: 3000 })}

Nothing here yet. If the user reveals preferences about how they code
(or how they want me to code), I should store them here.

Examples: "always use bun not npm", "never git commit without asking first",
"prefer functional style over classes".
`
    );
  }

  const refDir = join(memDir, "reference");
  mkdirSync(refDir, { recursive: true });

  const readmeFile = join(refDir, "README.md");
  if (!existsSync(readmeFile)) {
    writeFileSync(
      readmeFile,
      `${buildFrontmatter({ description: "How to use the reference directory", limit: 1000 })}

Store reference material here. Files in this directory are listed in the tree
but NOT loaded into the system prompt. The agent can read them on demand.

Examples: project conventions, architecture notes, frequently used patterns.
`
    );
  }
}

// --- Extension ---

export default function contextRepoExtension(pi: ExtensionAPI) {
  let memDir = "";
  let initialized = false;
  let turnCount = 0;
  let reflectionInterval = DEFAULT_REFLECTION_INTERVAL;

  // Initialize on session start
  pi.on("session_start", async (_event, ctx) => {
    memDir = join(ctx.cwd, MEMORY_DIR_NAME);

    // Load per-agent settings
    const settings = loadSettings(memDir);
    reflectionInterval = settings.reflectionInterval;

    if (!existsSync(memDir)) {
      scaffoldMemory(memDir);
    }

    if (!(await isGitRepo(pi, memDir))) {
      await initRepo(pi, memDir);
    } else {
      // Self-healing: ensure hook is installed on existing repos
      installPreCommitHook(memDir);

      // Pull from remote on startup if configured
      if (await hasRemote(pi, memDir)) {
        try {
          await pullFromRemote(pi, memDir);
        } catch {
          // non-fatal — agent will see status
        }
      }
    }

    initialized = true;
    turnCount = 0;

    const status = await getStatus(pi, memDir);
    ctx.ui.setWidget(EXT_TYPE, statusWidget(status));
  });

  // Inject memory into system prompt before each agent turn
  pi.on("before_agent_start", async (event) => {
    if (!initialized || !existsSync(memDir)) return;

    turnCount++;

    const tree = buildTree(memDir);
    const systemContent = loadSystemFiles(memDir);

    // Detect and warn about prompt drift
    const drifts = detectPromptDrift(event.systemPrompt);
    let driftWarning = "";
    if (drifts.length > 0) {
      driftWarning = `\n<system-reminder>\nMEMORY PROMPT DRIFT DETECTED:\n${drifts.map((d) => `- ${d.message}`).join("\n")}\nThe context-repo extension manages memory sections. Legacy fragments may cause confusion.\n</system-reminder>\n`;
    }

    let memoryBlock = `
## Context Repository (Agent Memory)

Your persistent memory is stored in \`${MEMORY_DIR_NAME}/\` (git-backed).
Files in \`${SYSTEM_DIR}/\` are pinned below. Other files are in the tree — use the read tool to load them.
The memory directory is available as \`$MEMORY_DIR\` in shell commands.

### Memory Filesystem
\`\`\`
${MEMORY_DIR_NAME}/
${tree.join("\n")}
\`\`\`

### Pinned Memory (system/)
${systemContent || "(No system files yet.)"}

### Memory Guidelines
- To remember something: use the memory_write tool (validates frontmatter, enforces limits)
- To remove a file: use the memory_delete tool
- Each file needs frontmatter: \`description\` (what it contains) and \`limit\` (max chars)
- Put always-needed context in \`${SYSTEM_DIR}/\`, reference material elsewhere
- Use hierarchical \`/\` naming: \`system/project/tooling.md\`, not \`system/project-tooling.md\`
- After changes, use memory_commit to save
- Apply memory naturally — don't narrate "I remember that..." — just use what you know
- Files marked \`read_only\` cannot be modified

### Syncing
\`\`\`bash
cd "$MEMORY_DIR"
git status                           # See what changed
git add system/
git commit -m "<type>: <what changed>"  # e.g. "fix: update user prefs"
git push                             # Push to remote
git pull                             # Get latest from remote
\`\`\`

### Conflict Resolution
If pull/push fails with conflicts:
1. \`git pull --rebase\` to rebase local on remote
2. If conflicts, edit files to resolve, then \`git add <file>\` and \`git rebase --continue\`
3. Prefer keeping newer content when resolving
4. If stuck: \`git rebase --abort\` to undo, then \`/memfs sync\` to retry
`;

    // Sync reminder (dirty or ahead-of-remote)
    try {
      const status = await getStatus(pi, memDir);
      if (status.dirty || status.aheadOfRemote) {
        memoryBlock += `\n<system-reminder>\nMEMORY SYNC: ${status.summary}\n`;
        if (status.dirty) {
          memoryBlock += `Commit when convenient with memory_commit.\n`;
        }
        if (status.aheadOfRemote) {
          memoryBlock += `Push when convenient: \`git -C ${MEMORY_DIR_NAME} push\`\n`;
        }
        memoryBlock += `</system-reminder>\n`;
      }
    } catch {
      // ignore
    }

    // Periodic reflection reminder
    if (reflectionInterval > 0 && turnCount > 0 && turnCount % reflectionInterval === 0) {
      memoryBlock += "\n" + MEMORY_REFLECTION_REMINDER + "\n";
    }

    return {
      systemPrompt: event.systemPrompt + "\n" + driftWarning + memoryBlock,
      env: {
        MEMORY_DIR: memDir,
        PI_MEMORY_DIR: memDir,
      },
    };
  });

  // Update status widget after each agent turn
  pi.on("agent_end", async (_event, ctx) => {
    if (!initialized || !existsSync(memDir)) return;
    try {
      const status = await getStatus(pi, memDir);
      ctx.ui.setWidget(EXT_TYPE, statusWidget(status));
    } catch {
      // ignore
    }
  });

  // --- Tools ---

  pi.registerTool({
    name: "memory_write",
    label: "Memory Write",
    description:
      "Write or update a memory file. Validates frontmatter, enforces character limits, " +
      "rejects writes to read-only files. Use system/ prefix for always-loaded context.",
    parameters: Type.Object({
      path: Type.String({
        description:
          "Relative path within .pi/memory/ (e.g. 'system/preferences.md', 'reference/architecture.md')",
      }),
      description: Type.String({ description: "What this memory file contains (for frontmatter)" }),
      content: Type.String({ description: "The memory content (markdown)" }),
      limit: Type.Optional(
        Type.Number({ description: "Character limit for this file (default: 3000)" })
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      if (!initialized) {
        return toolResult("Context repo not initialized.");
      }

      // Ensure .md extension
      const pathWithExt = params.path.endsWith(".md") ? params.path : params.path + ".md";
      const filePath = join(memDir, pathWithExt);

      // Determine effective limit
      let effectiveLimit = params.limit || 3000;
      let existingContent: string | undefined;

      if (existsSync(filePath)) {
        existingContent = readFileSync(filePath, "utf-8");
        const { frontmatter: existingFm } = parseFrontmatter(existingContent);

        // Check read_only
        if (existingFm.read_only) {
          return toolResult(`Error: ${pathWithExt} is read_only and cannot be modified.`);
        }

        // Use existing limit if not overridden
        if (!params.limit && existingFm.limit) {
          effectiveLimit = existingFm.limit;
        }
      }

      // Enforce character limit on content
      if (params.content.length > effectiveLimit) {
        return toolResult(
          `Error: content is ${params.content.length} chars, exceeds limit of ${effectiveLimit}. Trim content or increase limit.`
        );
      }

      // Build file content
      const fm = buildFrontmatter({
        description: params.description,
        limit: effectiveLimit,
      });
      const fileContent = `${fm}\n\n${params.content}\n`;

      // Validate frontmatter
      const errors = validateFrontmatter(fileContent, pathWithExt, existingContent);
      if (errors.length > 0) {
        return toolResult(`Frontmatter validation failed:\n${errors.join("\n")}`);
      }

      // Write
      const parentDir = join(filePath, "..");
      mkdirSync(parentDir, { recursive: true });
      writeFileSync(filePath, fileContent);

      // Auto-stage
      const relPath = relative(memDir, filePath);
      await git(pi, memDir, ["add", relPath]);

      // Update widget
      const status = await getStatus(pi, memDir);
      ctx.ui.setWidget(EXT_TYPE, statusWidget(status));

      return toolResult(
        `Wrote ${relPath} (${params.content.length}/${effectiveLimit} chars). Staged for commit.`
      );
    },
  });

  pi.registerTool({
    name: "memory_delete",
    label: "Memory Delete",
    description: "Delete a memory file and stage the deletion. Cannot delete read-only files.",
    parameters: Type.Object({
      path: Type.String({
        description: "Relative path within .pi/memory/ (e.g. 'reference/old-notes.md')",
      }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      if (!initialized) {
        return toolResult("Context repo not initialized.");
      }

      const pathWithExt = params.path.endsWith(".md") ? params.path : params.path + ".md";
      const filePath = join(memDir, pathWithExt);

      if (!existsSync(filePath)) {
        return toolResult(`Error: ${pathWithExt} does not exist.`);
      }

      // Check read_only
      const content = readFileSync(filePath, "utf-8");
      const { frontmatter } = parseFrontmatter(content);
      if (frontmatter.read_only) {
        return toolResult(`Error: ${pathWithExt} is read_only and cannot be deleted.`);
      }

      // Remove and stage
      const relPath = relative(memDir, filePath);
      rmSync(filePath);
      await git(pi, memDir, ["add", relPath]);

      // Update widget
      const status = await getStatus(pi, memDir);
      ctx.ui.setWidget(EXT_TYPE, statusWidget(status));

      return toolResult(`Deleted ${relPath}. Staged for commit.`);
    },
  });

  pi.registerTool({
    name: "memory_commit",
    label: "Memory Commit",
    description: "Commit staged memory changes with a descriptive message.",
    parameters: Type.Object({
      message: Type.String({
        description:
          'Commit message (e.g. "update: user prefers dark mode", "refactor: reorganize project notes")',
      }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      if (!initialized) {
        return toolResult("Context repo not initialized.");
      }

      try {
        await git(pi, memDir, ["add", "-A"]);
        await git(pi, memDir, ["commit", "-m", params.message]);
        const status = await getStatus(pi, memDir);
        ctx.ui.setWidget(EXT_TYPE, statusWidget(status));
        let result = `Committed: ${params.message}`;
        if (status.aheadOfRemote) {
          result += `\n\n${status.aheadCount} unpushed commit(s). Push with: git -C ${MEMORY_DIR_NAME} push`;
        }
        return toolResult(result);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        if (msg.includes("nothing to commit")) {
          return toolResult("Nothing to commit — memory is clean.");
        }
        return toolResult(`Commit failed: ${msg}`);
      }
    },
  });

  pi.registerTool({
    name: "memory_search",
    label: "Memory Search",
    description:
      "Search memory files by content or filename. Returns matching files with snippets.",
    parameters: Type.Object({
      query: Type.String({ description: "Search term (searches filenames and content)" }),
    }),
    async execute(_toolCallId, params) {
      if (!initialized) {
        return toolResult("Context repo not initialized.");
      }

      try {
        const { stdout } = await git(pi, memDir, [
          "grep",
          "-il",
          "--no-color",
          params.query,
          "--",
          "*.md",
        ]);

        const files = stdout
          .trim()
          .split("\n")
          .filter((f) => f.trim());

        if (files.length === 0) {
          return toolResult(`No memory files matching "${params.query}".`);
        }

        const results: string[] = [];
        for (const file of files.slice(0, 10)) {
          const content = readFileSync(join(memDir, file), "utf-8");
          const { frontmatter } = parseFrontmatter(content);
          results.push(`- **${file}** — ${frontmatter.description || "(no description)"}`);
        }

        return toolResult(
          `Found ${files.length} match(es):\n${results.join("\n")}\n\nUse the read tool to load full content.`
        );
      } catch {
        return toolResult(`No memory files matching "${params.query}".`);
      }
    },
  });

  pi.registerTool({
    name: "memory_log",
    label: "Memory Log",
    description: "Show recent memory commit history.",
    parameters: Type.Object({
      count: Type.Optional(Type.Number({ description: "Number of commits to show (default: 10)" })),
    }),
    async execute(_toolCallId, params) {
      if (!initialized) {
        return toolResult("Context repo not initialized.");
      }

      const n = params.count || 10;
      try {
        const { stdout } = await git(pi, memDir, [
          "log",
          "--oneline",
          `-${n}`,
          "--format=%h %s (%ar)",
        ]);
        return toolResult(stdout.trim() || "No commits yet.");
      } catch {
        return toolResult("No commits yet.");
      }
    },
  });

  pi.registerTool({
    name: "memory_recall",
    label: "Memory Recall",
    description:
      "Search past conversation history from pi session files. " +
      "Finds messages matching a query across session JSONL files. " +
      "Use to recall past discussions, decisions, and context.",
    parameters: Type.Object({
      query: Type.String({ description: "Search term to find in past conversations" }),
      limit: Type.Optional(Type.Number({ description: "Max results to return (default: 10)" })),
      sessionsDir: Type.Optional(
        Type.String({
          description:
            "Override sessions directory (default: auto-detected from ~/.pi/agent/sessions/)",
        })
      ),
    }),
    async execute(_toolCallId, params) {
      if (!initialized) {
        return toolResult("Context repo not initialized.");
      }

      const maxResults = params.limit || 10;

      // Find sessions directory for current project
      const homeDir = process.env.HOME || "";
      const piSessionsRoot = join(homeDir, ".pi", "agent", "sessions");

      let sessionsDir = params.sessionsDir;
      if (!sessionsDir) {
        // Auto-detect: find the session dir matching current cwd
        if (existsSync(piSessionsRoot)) {
          const cwdEncoded = memDir.replace(/\/.pi\/memory$/, "").replace(/\//g, "-");
          const entries = readdirSync(piSessionsRoot);
          const match = entries.find((e) => e.includes(cwdEncoded));
          if (match) {
            sessionsDir = join(piSessionsRoot, match);
          }
        }
      }

      if (!sessionsDir || !existsSync(sessionsDir)) {
        // Try Claude Code history as fallback
        const claudeHistory = join(homeDir, ".claude", "projects");
        if (existsSync(claudeHistory)) {
          return toolResult(
            `No pi session history found for this project.\n` +
              `Claude Code history detected at: ${claudeHistory}\n` +
              `Use \`rg '${params.query}' ${claudeHistory}\` to search manually.`
          );
        }
        return toolResult("No session history found for this project.");
      }

      // Search session files with ripgrep (fast) or grep fallback
      try {
        const { stdout } = await pi.exec("rg", [
          "--no-filename",
          "-i",
          "--max-count",
          String(maxResults * 3), // over-fetch to filter
          params.query,
          sessionsDir,
        ]);

        const lines = stdout.trim().split("\n").filter(Boolean);
        const results: string[] = [];

        for (const line of lines) {
          if (results.length >= maxResults) break;
          try {
            const entry = JSON.parse(line);
            if (entry.type !== "message") continue;
            const msg = entry.message;
            if (!msg?.content) continue;

            // Extract text content
            let text = "";
            if (typeof msg.content === "string") {
              text = msg.content;
            } else if (Array.isArray(msg.content)) {
              text = msg.content
                .filter((c: { type: string; text?: string }) => c.type === "text" && c.text)
                .map((c: { text: string }) => c.text)
                .join("\n");
            }

            if (!text || !text.toLowerCase().includes(params.query.toLowerCase())) continue;

            // Truncate to snippet
            const idx = text.toLowerCase().indexOf(params.query.toLowerCase());
            const start = Math.max(0, idx - 100);
            const end = Math.min(text.length, idx + params.query.length + 100);
            const snippet =
              (start > 0 ? "..." : "") + text.slice(start, end) + (end < text.length ? "..." : "");

            const date = entry.timestamp
              ? new Date(entry.timestamp).toISOString().slice(0, 16)
              : "unknown";

            results.push(`**[${date}]** (${msg.role}):\n${snippet}\n`);
          } catch {
            // skip malformed lines
          }
        }

        if (results.length === 0) {
          return toolResult(
            `No conversations matching "${params.query}" found in session history.`
          );
        }

        return toolResult(
          `Found ${results.length} match(es) for "${params.query}":\n\n${results.join("\n---\n")}`
        );
      } catch {
        // rg not available, try grep
        try {
          const { stdout } = await pi.exec("grep", ["-ri", "-l", params.query, sessionsDir]);
          const files = stdout.trim().split("\n").filter(Boolean);
          return toolResult(
            `Found matches in ${files.length} session file(s). Use the read tool to examine:\n${files
              .slice(0, 5)
              .map((f) => `- ${f}`)
              .join("\n")}`
          );
        } catch {
          return toolResult(`No conversations matching "${params.query}" found.`);
        }
      }
    },
  });

  pi.registerTool({
    name: "memory_backup",
    label: "Memory Backup",
    description:
      "Create a timestamped backup of the memory directory. Use before risky operations like defragmentation.",
    parameters: Type.Object({}),
    async execute() {
      if (!initialized) {
        return toolResult("Context repo not initialized.");
      }

      const backupRoot = getBackupDir(memDir);
      const backupName = `backup-${formatBackupTimestamp()}`;
      const backupPath = join(backupRoot, backupName);

      if (existsSync(backupPath)) {
        return toolResult(`Backup already exists: ${backupName}`);
      }

      mkdirSync(backupRoot, { recursive: true });
      cpSync(memDir, backupPath, { recursive: true });

      return toolResult(
        `Backup created: ${backupName}\nRestore with /memory-restore ${backupName}`
      );
    },
  });

  // --- Commands ---

  pi.registerCommand("memory", {
    description: "Show memory status, tree, and recent history",
    handler: async (_args, ctx) => {
      if (!initialized || !existsSync(memDir)) {
        ctx.ui.notify("Context repo not initialized.", "warning");
        return;
      }

      const tree = buildTree(memDir);
      const status = await getStatus(pi, memDir);

      let output = `Context Repository (${MEMORY_DIR_NAME})\n\n`;
      output += tree.join("\n") + "\n\n";
      if (status.dirty) {
        output += `${status.files.length} uncommitted change(s):\n${status.files.map((f) => `  ${f}`).join("\n")}`;
      } else {
        output += "Clean (all changes committed)";
      }
      if (status.hasRemote) {
        output += status.aheadOfRemote
          ? `\n${status.aheadCount} commit(s) ahead of remote — push with: git -C ${MEMORY_DIR_NAME} push`
          : "\nIn sync with remote";
      }

      try {
        const { stdout } = await git(pi, memDir, [
          "log",
          "--oneline",
          "-5",
          "--format=%h %s (%ar)",
        ]);
        if (stdout.trim()) {
          output += "\n\nRecent history:\n" + stdout.trim();
        }
      } catch {
        // no history yet
      }

      ctx.ui.notify(output, "info");
    },
  });

  pi.registerCommand("init", {
    description:
      "Initialize or re-analyze agent memory. Gathers project context, asks questions, " +
      "researches codebase, and populates 15-25 hierarchical memory files. " +
      "Run again after major project changes.",
    handler: async (_args, ctx) => {
      // Ensure scaffold + git repo exist
      if (!existsSync(memDir)) {
        scaffoldMemory(memDir);
      }
      if (!(await isGitRepo(pi, memDir))) {
        await initRepo(pi, memDir);
      } else {
        installPreCommitHook(memDir);
      }
      initialized = true;

      ctx.ui.notify("Gathering project context...", "info");

      // Gather git context
      let gitContext = "";
      try {
        const cwd = memDir.replace(/\/.pi\/memory$/, "");
        const { stdout: branch } = await pi.exec("git", ["-C", cwd, "branch", "--show-current"]);
        const { stdout: status } = await pi.exec("git", ["-C", cwd, "status", "--short"]);
        const { stdout: commits } = await pi.exec("git", ["-C", cwd, "log", "--oneline", "-10"]);
        const { stdout: contributors } = await pi.exec("git", [
          "-C",
          cwd,
          "shortlog",
          "-sn",
          "--all",
        ]);
        gitContext = `
## Current Project Context

**Working directory**: ${cwd}

### Git Status
- **Current branch**: ${branch.trim()}
- **Working tree**: ${status.trim() || "(clean)"}

### Recent Commits
${commits.trim()}

### Top Contributors
${contributors.trim().split("\n").slice(0, 10).join("\n")}
`;
      } catch {
        gitContext = "\n## Current Project Context\n\n(Not a git repository)\n";
      }

      // Detect prior agent session history
      const historyPaths: string[] = [];
      const homeDir = process.env.HOME || "";
      const candidates = [
        { path: join(homeDir, ".claude", "projects"), label: "Claude Code project sessions" },
        { path: join(homeDir, ".pi", "agent", "sessions"), label: "Pi agent sessions" },
        { path: join(homeDir, ".codex", "history.jsonl"), label: "Codex history" },
      ];
      for (const c of candidates) {
        if (existsSync(c.path)) historyPaths.push(`- **${c.label}**: \`${c.path}\``);
      }

      const historySection =
        historyPaths.length > 0
          ? `
## Prior Agent Sessions Detected

The following agent history is available on this machine:
${historyPaths.join("\n")}

You can ask the user if they want you to analyze these for preferences and project context.
`
          : "";

      // Count existing memory files
      let existingFiles = 0;
      try {
        const { stdout } = await pi.exec("find", [memDir, "-name", "*.md", "-type", "f"]);
        existingFiles = stdout.trim().split("\n").filter(Boolean).length;
      } catch {
        // ignore
      }

      const memorySection = `
## Memory Location

**Memory directory**: \`${memDir}\`
**Existing files**: ${existingFiles}
**Remote**: ${(await hasRemote(pi, memDir)) ? "configured" : "none"}

Use the \`memory_write\` tool to create/update files, then \`memory_commit\` to save.
`;

      // Send the init trigger as a user message
      pi.sendUserMessage(
        `<system-reminder>
The user has requested memory initialization via /init.
${memorySection}
${gitContext}
${historySection}
## Instructions

Load and follow the \`initializing-memory\` skill for comprehensive instructions.

Key steps:
1. Ask upfront questions (research depth, identity, communication style, rules)
2. Research the project based on chosen depth
3. Create 15-25 hierarchical memory files using \`memory_write\`
4. Reflect and verify completeness
5. Commit with \`memory_commit\` and push if remote is configured
</system-reminder>`
      );
    },
  });

  pi.registerCommand("remember", {
    description:
      "Explicitly tell the agent to commit something to memory (usage: /remember [what to remember])",
    handler: async (args, _ctx) => {
      if (!initialized || !existsSync(memDir)) {
        _ctx.ui.notify("Context repo not initialized.", "warning");
        return;
      }

      const userText = args.trim();
      const prompt = userText
        ? `${REMEMBER_PROMPT}\n\nThe user wants to remember: "${userText}"`
        : REMEMBER_PROMPT;

      pi.sendUserMessage(prompt);
    },
  });

  pi.registerCommand("memory-diff", {
    description: "Show uncommitted memory changes",
    handler: async (_args, ctx) => {
      if (!initialized || !existsSync(memDir)) {
        ctx.ui.notify("Context repo not initialized.", "warning");
        return;
      }

      try {
        const { stdout } = await git(pi, memDir, ["diff"]);
        const { stdout: staged } = await git(pi, memDir, ["diff", "--cached"]);
        const diff = [staged, stdout].filter(Boolean).join("\n");
        ctx.ui.notify(diff || "No changes.", "info");
      } catch {
        ctx.ui.notify("No changes.", "info");
      }
    },
  });

  pi.registerCommand("memory-backup", {
    description: "Create a timestamped backup of memory",
    handler: async (_args, ctx) => {
      if (!initialized || !existsSync(memDir)) {
        ctx.ui.notify("Context repo not initialized.", "warning");
        return;
      }

      const backupRoot = getBackupDir(memDir);
      const backupName = `backup-${formatBackupTimestamp()}`;
      const backupPath = join(backupRoot, backupName);

      mkdirSync(backupRoot, { recursive: true });
      cpSync(memDir, backupPath, { recursive: true });
      ctx.ui.notify(`Backup created: ${backupName}`, "info");
    },
  });

  pi.registerCommand("memory-backups", {
    description: "List available memory backups",
    handler: async (_args, ctx) => {
      const backups = listBackups(memDir);
      if (backups.length === 0) {
        ctx.ui.notify("No backups found.", "info");
        return;
      }
      const lines = backups.map((b) => `  ${b.name} (${b.createdAt})`);
      ctx.ui.notify(`Memory backups:\n${lines.join("\n")}`, "info");
    },
  });

  pi.registerCommand("memory-restore", {
    description: "Restore memory from a backup (usage: /memory-restore <backup-name>)",
    handler: async (args, ctx) => {
      if (!initialized) {
        ctx.ui.notify("Context repo not initialized.", "warning");
        return;
      }

      const backupName = args.trim();
      if (!backupName) {
        ctx.ui.notify(
          "Usage: /memory-restore <backup-name>\nList backups with /memory-backups",
          "warning"
        );
        return;
      }

      const backupPath = join(getBackupDir(memDir), backupName);
      if (!existsSync(backupPath) || !statSync(backupPath).isDirectory()) {
        ctx.ui.notify(`Backup not found: ${backupName}`, "error");
        return;
      }

      rmSync(memDir, { recursive: true, force: true });
      cpSync(backupPath, memDir, { recursive: true });
      installPreCommitHook(memDir);
      ctx.ui.notify(`Restored from: ${backupName}`, "info");
    },
  });

  pi.registerCommand("memory-export", {
    description: "Export memory to a directory (usage: /memory-export <dir>)",
    handler: async (args, ctx) => {
      if (!initialized || !existsSync(memDir)) {
        ctx.ui.notify("Context repo not initialized.", "warning");
        return;
      }

      const outDir = args.trim();
      if (!outDir) {
        ctx.ui.notify("Usage: /memory-export <output-dir>", "warning");
        return;
      }

      mkdirSync(outDir, { recursive: true });
      cpSync(memDir, outDir, { recursive: true });
      ctx.ui.notify(`Exported memory to: ${outDir}`, "info");
    },
  });

  pi.registerCommand("memfs", {
    description: "Manage memory filesystem (usage: /memfs [status|sync|reset])",
    handler: async (args, ctx) => {
      const subcommand = args.trim().split(/\s+/)[0] || "status";

      if (subcommand === "status") {
        if (!initialized || !existsSync(memDir)) {
          ctx.ui.notify("Memory filesystem: not initialized", "info");
          return;
        }
        const status = await getStatus(pi, memDir);
        const remote = await hasRemote(pi, memDir);
        let output = `Memory filesystem: enabled\n`;
        output += `Directory: ${memDir}\n`;
        output += `Status: ${status.summary}\n`;
        output += `Remote: ${remote ? "configured" : "none"}\n`;
        if (status.dirty) {
          output += `Uncommitted:\n${status.files.map((f) => `  ${f}`).join("\n")}\n`;
        }
        ctx.ui.notify(output, "info");
        return;
      }

      if (subcommand === "sync") {
        if (!initialized || !existsSync(memDir)) {
          ctx.ui.notify("Context repo not initialized.", "warning");
          return;
        }

        // Commit any uncommitted changes
        try {
          const status = await getStatus(pi, memDir);
          if (status.dirty) {
            await git(pi, memDir, ["add", "-A"]);
            await git(pi, memDir, ["commit", "-m", "sync: auto-commit before sync"]);
          }
        } catch {
          // nothing to commit
        }

        // Pull then push
        if (await hasRemote(pi, memDir)) {
          const pullResult = await pullFromRemote(pi, memDir);
          try {
            await git(pi, memDir, ["push"]);
            ctx.ui.notify(`Synced. Pull: ${pullResult.summary}. Push: success.`, "info");
          } catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            ctx.ui.notify(`Pull: ${pullResult.summary}. Push failed: ${msg}`, "warning");
          }
        } else {
          ctx.ui.notify("No remote configured. Nothing to sync.", "info");
        }
        return;
      }

      if (subcommand === "reset") {
        if (!initialized || !existsSync(memDir)) {
          ctx.ui.notify("Context repo not initialized.", "warning");
          return;
        }

        // Reset to last commit (discard uncommitted changes)
        try {
          await git(pi, memDir, ["checkout", "--", "."]);
          await git(pi, memDir, ["clean", "-fd"]);
          const status = await getStatus(pi, memDir);
          ctx.ui.setWidget(EXT_TYPE, statusWidget(status));
          ctx.ui.notify("Memory reset to last commit.", "info");
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          ctx.ui.notify(`Reset failed: ${msg}`, "error");
        }
        return;
      }

      ctx.ui.notify(
        "Usage: /memfs [status|sync|reset]\n\n" +
          "  status  — Show memory filesystem status (default)\n" +
          "  sync    — Commit, pull, and push\n" +
          "  reset   — Discard uncommitted changes",
        "info"
      );
    },
  });

  pi.registerCommand("memory-import", {
    description: "Import memory from another directory (usage: /memory-import <source-dir>)",
    handler: async (args, ctx) => {
      if (!initialized) {
        ctx.ui.notify("Context repo not initialized.", "warning");
        return;
      }

      const srcDir = args.trim();
      if (!srcDir) {
        ctx.ui.notify("Usage: /memory-import <source-dir>", "warning");
        return;
      }

      if (!existsSync(srcDir)) {
        ctx.ui.notify(`Source directory not found: ${srcDir}`, "error");
        return;
      }

      // Copy files from source (preserving existing)
      cpSync(srcDir, memDir, { recursive: true, force: false });
      installPreCommitHook(memDir);

      // Stage and commit
      try {
        await git(pi, memDir, ["add", "-A"]);
        await git(pi, memDir, ["commit", "-m", `import: memory from ${srcDir}`]);
      } catch {
        // may have nothing new
      }

      ctx.ui.notify(`Imported memory from: ${srcDir}`, "info");
    },
  });

  // Cleanup
  pi.on("session_shutdown", (_event, ctx) => {
    ctx.ui.setWidget(EXT_TYPE, undefined);
  });
}
