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
 * Key ideas from Letta's design:
 * - Files as memory units with frontmatter (description, limit)
 * - `system/` subdir pinned to system prompt (always-loaded context)
 * - Progressive disclosure via file tree (agent reads what it needs)
 * - Git versioning with informative commits
 * - Pre-commit validation of frontmatter
 */

import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, relative } from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

// --- Constants ---

const MEMORY_DIR_NAME = ".pi/memory";
const SYSTEM_DIR = "system";
const EXT_TYPE = "context-repo";

// --- Frontmatter helpers ---

interface Frontmatter {
  description?: string;
  limit?: number;
  read_only?: boolean;
  [key: string]: unknown;
}

function parseFrontmatter(content: string): { frontmatter: Frontmatter; body: string } {
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

function buildFrontmatter(fm: Frontmatter): string {
  const lines: string[] = ["---"];
  if (fm.description) lines.push(`description: ${fm.description}`);
  if (fm.limit) lines.push(`limit: ${fm.limit}`);
  if (fm.read_only) lines.push(`read_only: true`);
  lines.push("---");
  return lines.join("\n");
}

// --- File tree ---

function buildTree(dir: string, prefix = ""): string[] {
  const lines: string[] = [];
  if (!existsSync(dir)) return lines;

  const entries = readdirSync(dir, { withFileTypes: true })
    .filter((e) => !e.name.startsWith("."))
    .sort((a, b) => {
      // dirs first, then alpha
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

// --- Load system/ files ---

function loadSystemFiles(memDir: string): string {
  const sysDir = join(memDir, SYSTEM_DIR);
  if (!existsSync(sysDir)) return "";

  const files = readdirSync(sysDir)
    .filter((f) => f.endsWith(".md"))
    .sort();

  const sections: string[] = [];
  for (const file of files) {
    const content = readFileSync(join(sysDir, file), "utf-8");
    const { body } = parseFrontmatter(content);
    if (body.trim()) {
      sections.push(`<system/memory/${file}>\n${body.trim()}\n</system/memory/${file}>`);
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

  // Create reference dir for non-system memory
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

  // Initialize on session start: ensure dir exists, git init if needed
  pi.on("session_start", async (_event, ctx) => {
    memDir = join(ctx.cwd, MEMORY_DIR_NAME);

    if (!existsSync(memDir)) {
      scaffoldMemory(memDir);
      ctx.ui.notify("Context repo initialized at " + MEMORY_DIR_NAME, "info");
    }

    if (!(await isGitRepo(pi, memDir))) {
      await initRepo(pi, memDir);
    }

    initialized = true;

    // Show status widget
    const status = await getStatus(pi, memDir);
    ctx.ui.setWidget(EXT_TYPE, [
      `📝 Memory: ${status.dirty ? `${status.files.length} uncommitted` : "clean"}`,
    ]);
  });

  // Inject memory into system prompt before each agent turn
  pi.on("before_agent_start", async (event) => {
    if (!initialized || !existsSync(memDir)) return;

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
- To remember something: write/update a .md file in \`${MEMORY_DIR_NAME}/\`
- Each file needs frontmatter: \`description\` (what it contains) and \`limit\` (max chars)
- Put always-needed context in \`${SYSTEM_DIR}/\`, reference material elsewhere
- After changes, commit: \`cd ${MEMORY_DIR_NAME} && git add -A && git commit -m "type: what changed"\`
- Apply memory naturally — don't narrate "I remember that..." — just use what you know
`;

    // Dirty reminder
    try {
      const status = await getStatus(pi, memDir);
      if (status.dirty) {
        memoryBlock += `
### ⚠️ Uncommitted Memory Changes
You have ${status.files.length} uncommitted change(s). Commit when convenient:
\`cd ${MEMORY_DIR_NAME} && git add -A && git commit -m "update: ..."\`
`;
      }
    } catch {
      // ignore status check failures
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
        `📝 Memory: ${status.dirty ? `${status.files.length} uncommitted` : "clean"}`,
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
      "Write or update a memory file in the context repository. Creates parent directories automatically. " +
      "Use system/ prefix for always-loaded context, other paths for reference material.",
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
        return { content: [{ type: "text", text: "Context repo not initialized." }] };
      }

      const filePath = join(memDir, params.path);

      // Check read_only
      if (existsSync(filePath)) {
        const existing = readFileSync(filePath, "utf-8");
        const { frontmatter } = parseFrontmatter(existing);
        if (frontmatter.read_only) {
          return { content: [{ type: "text", text: `Error: ${params.path} is read-only.` }] };
        }
      }

      // Ensure parent dirs exist
      const parentDir = join(filePath, "..");
      mkdirSync(parentDir, { recursive: true });

      // Ensure .md extension
      const finalPath = params.path.endsWith(".md") ? filePath : filePath + ".md";

      const fm = buildFrontmatter({
        description: params.description,
        limit: params.limit || 3000,
      });
      writeFileSync(finalPath, `${fm}\n\n${params.content}\n`);

      // Auto-stage
      const relPath = relative(memDir, finalPath);
      await git(pi, memDir, ["add", relPath]);

      // Update widget
      const status = await getStatus(pi, memDir);
      ctx.ui.setWidget(EXT_TYPE, [
        `📝 Memory: ${status.dirty ? `${status.files.length} uncommitted` : "clean"}`,
      ]);

      return {
        content: [
          {
            type: "text",
            text: `Wrote ${relPath} (${params.content.length} chars). Staged for commit.`,
          },
        ],
      };
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
        return { content: [{ type: "text", text: "Context repo not initialized." }] };
      }

      try {
        // Stage everything and commit
        await git(pi, memDir, ["add", "-A"]);
        await git(pi, memDir, ["commit", "-m", params.message]);

        ctx.ui.setWidget(EXT_TYPE, ["📝 Memory: clean"]);

        return {
          content: [{ type: "text", text: `Committed: ${params.message}` }],
        };
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        if (msg.includes("nothing to commit")) {
          return { content: [{ type: "text", text: "Nothing to commit — memory is clean." }] };
        }
        return { content: [{ type: "text", text: `Commit failed: ${msg}` }] };
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
        return { content: [{ type: "text", text: "Context repo not initialized." }] };
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
          return {
            content: [{ type: "text", text: `No memory files matching "${params.query}".` }],
          };
        }

        const results: string[] = [];
        for (const file of files.slice(0, 10)) {
          const content = readFileSync(join(memDir, file), "utf-8");
          const { frontmatter } = parseFrontmatter(content);
          results.push(`- **${file}** — ${frontmatter.description || "(no description)"}`);
        }

        return {
          content: [
            {
              type: "text",
              text: `Found ${files.length} match(es):\n${results.join("\n")}\n\nUse the read tool to load full content.`,
            },
          ],
        };
      } catch {
        return { content: [{ type: "text", text: `No memory files matching "${params.query}".` }] };
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
        return { content: [{ type: "text", text: "Context repo not initialized." }] };
      }

      const n = params.count || 10;
      try {
        const { stdout } = await git(pi, memDir, [
          "log",
          `--oneline`,
          `-${n}`,
          "--format=%h %s (%ar)",
        ]);

        return {
          content: [{ type: "text", text: stdout.trim() || "No commits yet." }],
        };
      } catch {
        return { content: [{ type: "text", text: "No commits yet." }] };
      }
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

      let output = `📝 Context Repository (${MEMORY_DIR_NAME})\n\n`;
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
      }
      initialized = true;
      ctx.ui.notify("Context repo scaffolded at " + MEMORY_DIR_NAME, "success");
    },
  });

  // Cleanup
  pi.on("session_shutdown", (_event, ctx) => {
    ctx.ui.setWidget(EXT_TYPE, undefined);
  });
}
