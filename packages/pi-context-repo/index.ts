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

function installPreCommitHook(memDir: string): void {
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

function loadSystemFiles(memDir: string, dir?: string): string {
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

async function getStatus(
  pi: ExtensionAPI,
  dir: string
): Promise<{ dirty: boolean; files: string[] }> {
  const { stdout } = await git(pi, dir, ["status", "--porcelain"]);
  const files = stdout
    .trim()
    .split("\n")
    .filter((l) => l.trim());
  return { dirty: files.length > 0, files };
}

// --- Backup helpers (adapted from Letta's memfs.ts) ---

function formatBackupTimestamp(date = new Date()): string {
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

// --- Scaffold ---

function scaffoldMemory(memDir: string): void {
  const sysDir = join(memDir, SYSTEM_DIR);
  mkdirSync(sysDir, { recursive: true });

  const personaFile = join(sysDir, "persona.md");
  if (!existsSync(personaFile)) {
    writeFileSync(
      personaFile,
      `${buildFrontmatter({ description: "Agent identity and behavior guidelines", limit: 3000 })}

You are a helpful coding assistant.
`
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

    const freshInit = !existsSync(memDir);
    if (freshInit) {
      scaffoldMemory(memDir);
    }

    if (!(await isGitRepo(pi, memDir))) {
      await initRepo(pi, memDir);
    } else {
      installPreCommitHook(memDir);
      // Auto-commit any uncommitted scaffold/leftover files
      const status = await getStatus(pi, memDir);
      if (status.dirty) {
        try {
          await git(pi, memDir, ["add", "-A"]);
          await git(pi, memDir, ["commit", "-m", "init: auto-commit on session start"]);
        } catch {
          // ignore — nothing to commit or hook failure
        }
      }
    }

    initialized = true;
    turnCount = 0;

    const status = await getStatus(pi, memDir);
    ctx.ui.setWidget(EXT_TYPE, [
      `Memory: ${status.dirty ? `${status.files.length} uncommitted` : "clean"}`,
    ]);
  });

  // Inject memory into system prompt before each agent turn
  pi.on("before_agent_start", async (event) => {
    if (!initialized || !existsSync(memDir)) return;

    turnCount++;

    const tree = buildTree(memDir);
    const systemContent = loadSystemFiles(memDir);

    let memoryBlock = `
## Context Repository (Agent Memory)

Your persistent memory is stored in \`${MEMORY_DIR_NAME}/\` (git-backed).
Files in \`${SYSTEM_DIR}/\` are pinned below. Other files are in the tree — use the read tool to load them.

### Memory Filesystem
\`\`\`
${MEMORY_DIR_NAME}/
${tree.join("\n")}
\`\`\`

### Pinned Memory (system/)
${systemContent || "(No system files yet.)"}

### Memory Guidelines
- To remember something: use the memory_write tool (validates frontmatter, enforces limits)
- Each file needs frontmatter: \`description\` (what it contains) and \`limit\` (max chars)
- Put always-needed context in \`${SYSTEM_DIR}/\`, reference material elsewhere
- Use hierarchical \`/\` naming: \`system/project/tooling.md\`, not \`system/project-tooling.md\`
- After changes, use memory_commit to save
- Apply memory naturally — don't narrate "I remember that..." — just use what you know
- Files marked \`read_only\` cannot be modified
`;

    // Dirty reminder
    try {
      const status = await getStatus(pi, memDir);
      if (status.dirty) {
        memoryBlock += `
### ⚠️ Uncommitted Memory Changes
You have ${status.files.length} uncommitted change(s). Commit when convenient with memory_commit.
`;
      }
    } catch {
      // ignore
    }

    // Periodic reflection reminder
    if (reflectionInterval > 0 && turnCount > 0 && turnCount % reflectionInterval === 0) {
      memoryBlock += "\n" + MEMORY_REFLECTION_REMINDER + "\n";
    }

    return {
      systemPrompt: event.systemPrompt + "\n" + memoryBlock,
    };
  });

  // Update status widget after each agent turn
  pi.on("agent_end", async (_event, ctx) => {
    if (!initialized || !existsSync(memDir)) return;
    try {
      const status = await getStatus(pi, memDir);
      ctx.ui.setWidget(EXT_TYPE, [
        `Memory: ${status.dirty ? `${status.files.length} uncommitted` : "clean"}`,
      ]);
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
      ctx.ui.setWidget(EXT_TYPE, [
        `Memory: ${status.dirty ? `${status.files.length} uncommitted` : "clean"}`,
      ]);

      return toolResult(
        `Wrote ${relPath} (${params.content.length}/${effectiveLimit} chars). Staged for commit.`
      );
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
        ctx.ui.setWidget(EXT_TYPE, ["Memory: clean"]);
        return toolResult(`Committed: ${params.message}`);
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
      output += status.dirty
        ? `⚠️ ${status.files.length} uncommitted change(s):\n${status.files.map((f) => `  ${f}`).join("\n")}`
        : "✓ Clean (all changes committed)";

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

  pi.registerCommand("memory-init", {
    description: "Re-scaffold memory directory if missing",
    handler: async (_args, ctx) => {
      scaffoldMemory(memDir);
      if (!(await isGitRepo(pi, memDir))) {
        await initRepo(pi, memDir);
      } else {
        installPreCommitHook(memDir);
      }
      initialized = true;
      ctx.ui.notify("Context repo scaffolded at " + MEMORY_DIR_NAME, "info");
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

  // Cleanup
  pi.on("session_shutdown", (_event, ctx) => {
    ctx.ui.setWidget(EXT_TYPE, undefined);
  });
}
