import { tool } from "@opencode-ai/plugin";

// Configurable paths - edit these if needed
const BUGWARRIOR_PULL = process.env.BUGWARRIOR_PULL || "bugwarrior-pull";
const BUGWARRIOR_CONFIG =
  process.env.BUGWARRIOR_CONFIG || `${Bun.env.HOME}/.config/bugwarrior/bugwarrior.toml`;
const DOTFILES = process.env.DOTFILES || `${Bun.env.HOME}/.config/dotfiles`;

// Get hostname for per-host UDA files
async function getHostname(): Promise<string> {
  const result = await Bun.$`hostname -s`.text();
  const hostname = result.trim().toLowerCase();
  // Map common hostname patterns
  if (hostname.includes("seqeratop")) return "seqeratop";
  if (hostname.includes("mactraitor")) return "mactraitorpro";
  return hostname;
}

/**
 * Sync tasks from external services (GitHub, Linear, Apple Reminders) to Taskwarrior
 */
export const pull = tool({
  description:
    "Sync tasks from external services (GitHub, Linear, Apple Reminders) to Taskwarrior. Returns a summary of synced tasks by workspace.",
  args: {
    dry_run: tool.schema.boolean().optional().describe("Preview changes without applying them"),
    flavor: tool.schema.string().optional().describe("Use a specific config flavor"),
    quiet: tool.schema.boolean().optional().describe("Reduce output verbosity"),
  },
  async execute(args) {
    const flags: string[] = [];
    if (args.dry_run) flags.push("--dry-run");
    if (args.flavor) flags.push("--flavor", args.flavor);
    if (args.quiet) flags.push("--quiet");

    try {
      const result = await Bun.$`${BUGWARRIOR_PULL} ${flags}`.text();
      return parsePullOutput(result);
    } catch (error: any) {
      return `Error running bugwarrior-pull: ${error.message}\n\nStderr: ${error.stderr?.toString() || "none"}`;
    }
  },
});

/**
 * Read and display bugwarrior configuration
 */
export const config = tool({
  description:
    "Read and display bugwarrior configuration. Can show full config or a specific target.",
  args: {
    target: tool.schema
      .string()
      .optional()
      .describe("Show only a specific target's config (e.g., 'github_nfcore_issues')"),
  },
  async execute(args) {
    try {
      const content = await Bun.file(BUGWARRIOR_CONFIG).text();

      if (args.target) {
        return extractTargetConfig(content, args.target);
      }
      return content;
    } catch (error: any) {
      return `Error reading config: ${error.message}`;
    }
  },
});

/**
 * Add a new target to bugwarrior config
 */
export const add_target = tool({
  description:
    "Add a new target to bugwarrior config. Generates appropriate config based on service type.",
  args: {
    name: tool.schema.string().describe("Target name (e.g., 'github_neworg_issues')"),
    service: tool.schema
      .string()
      .describe("Service type: github, linear, applereminders, gitlab, jira, etc."),
    workspace: tool.schema
      .string()
      .describe("Workspace assignment (e.g., seqera, nfcore, phd, personal, family)"),
    query: tool.schema.string().optional().describe("GitHub/GitLab query string"),
    orgs: tool.schema
      .array(tool.schema.string())
      .optional()
      .describe("GitHub organizations to include in query"),
    is_pr: tool.schema
      .boolean()
      .optional()
      .describe("For GitHub: is this a PR target (vs issues)?"),
  },
  async execute(args) {
    try {
      const content = await Bun.file(BUGWARRIOR_CONFIG).text();
      const newSection = generateTargetConfig(args);
      const updated = addTargetToConfig(content, args.name, newSection);

      await Bun.write(BUGWARRIOR_CONFIG, updated);

      return `Added target [${args.name}] to ${BUGWARRIOR_CONFIG}:\n\n${newSection}`;
    } catch (error: any) {
      return `Error adding target: ${error.message}`;
    }
  },
});

/**
 * Regenerate bugwarrior UDAs for the current host
 * Per-host system: each host generates its own file, both tracked in git
 */
export const regen_udas = tool({
  description:
    "Regenerate bugwarrior UDAs for the current host. Each host has its own UDA file (seqeratop.rc, mactraitorpro.rc), both tracked in git and included by taskrc.",
  args: {},
  async execute() {
    try {
      const hostname = await getHostname();
      const udaFile = `${DOTFILES}/config/taskwarrior/bugwarrior-udas-${hostname}.rc`;

      // Generate UDAs
      const result = await Bun.$`bugwarrior uda`.text();

      // Write to file
      await Bun.write(udaFile, result);

      // Count UDAs
      const udaCount = result.split("\n").filter((line) => line.startsWith("uda.")).length;

      // Extract service names from UDAs
      const services = new Set<string>();
      for (const line of result.split("\n")) {
        const match = line.match(/^uda\.([a-z]+)/);
        if (match) services.add(match[1]);
      }

      return `Regenerated ${udaCount} UDAs for ${hostname}
Services: ${[...services].sort().join(", ")}

Updated: ${udaFile}

Next steps:
  1. Review changes: jj diff
  2. Commit: jj describe -m "chore(bugwarrior): regenerate UDAs for ${hostname}"
  3. Push: jj git push`;
    } catch (error: any) {
      return `Error regenerating UDAs: ${error.message}\n\nStderr: ${error.stderr?.toString() || "none"}`;
    }
  },
});

// =============================================================================
// Helper Functions
// =============================================================================

/**
 * Parse bugwarrior-pull output and return a summary by workspace
 */
function parsePullOutput(output: string): string {
  const lines = output.split("\n");

  // Count tasks by workspace from output
  const workspaceCounts: Record<string, number> = {};
  const serviceCounts: Record<string, Record<string, number>> = {};
  let totalAdded = 0;
  let totalUpdated = 0;
  let totalDeleted = 0;

  for (const line of lines) {
    // Match lines like "Adding task ... workspace:nfcore"
    const addMatch = line.match(/Adding task/i);
    if (addMatch) totalAdded++;

    const updateMatch = line.match(/Updating task/i);
    if (updateMatch) totalUpdated++;

    const deleteMatch = line.match(/Deleting task/i);
    if (deleteMatch) totalDeleted++;

    // Try to extract workspace from the line
    const workspaceMatch = line.match(/workspace[=:](\w+)/i);
    if (workspaceMatch) {
      const ws = workspaceMatch[1];
      workspaceCounts[ws] = (workspaceCounts[ws] || 0) + 1;
    }

    // Match service processing lines like "Processing target 'github_nfcore_issues'"
    const targetMatch = line.match(/Processing target ['"]?(\w+)['"]?/i);
    if (targetMatch) {
      // Could track which targets were processed
    }
  }

  // Build summary
  const parts: string[] = [];

  if (totalAdded > 0 || totalUpdated > 0 || totalDeleted > 0) {
    parts.push(`Tasks: +${totalAdded} added, ~${totalUpdated} updated, -${totalDeleted} deleted`);
  }

  if (Object.keys(workspaceCounts).length > 0) {
    parts.push("\nBy workspace:");
    for (const [ws, count] of Object.entries(workspaceCounts).sort()) {
      parts.push(`  ${ws}: ${count}`);
    }
  }

  // If we couldn't parse much, return the raw output
  if (parts.length === 0) {
    return `Bugwarrior sync completed.\n\nRaw output:\n${output}`;
  }

  return `Bugwarrior sync completed.\n\n${parts.join("\n")}\n\nRaw output:\n${output}`;
}

/**
 * Extract a specific target's config section from TOML content
 */
function extractTargetConfig(content: string, target: string): string {
  const lines = content.split("\n");
  const sectionStart = `[${target}]`;
  let capturing = false;
  const result: string[] = [];

  for (const line of lines) {
    if (line.trim() === sectionStart) {
      capturing = true;
      result.push(line);
      continue;
    }

    if (capturing) {
      // Stop at next section
      if (line.match(/^\[[\w_]+\]$/)) {
        break;
      }
      result.push(line);
    }
  }

  if (result.length === 0) {
    return `Target '${target}' not found in config.\n\nAvailable targets can be found in [general].targets`;
  }

  return result.join("\n").trim();
}

/**
 * Generate a TOML config section for a new target
 */
function generateTargetConfig(args: {
  name: string;
  service: string;
  workspace: string;
  query?: string;
  orgs?: string[];
  is_pr?: boolean;
}): string {
  const lines: string[] = [`[${args.name}]`, `service = "${args.service}"`];

  if (args.service === "github") {
    lines.push(`login = "edmundmiller"`);
    lines.push(`token = "@oracle:eval:cat /usr/local/var/opnix/secrets/bugwarrior-github-token"`);
    lines.push(`username = "edmundmiller"`);

    // Description template
    if (args.is_pr) {
      lines.push(`description_template = "PR {{githubnamespace}}/{{githubrepo}}: {{githubtitle}}"`);
    } else {
      lines.push(`description_template = "{{githubnamespace}}/{{githubrepo}}: {{githubtitle}}"`);
    }

    // Build query
    if (args.query) {
      lines.push(`query = "${args.query}"`);
    } else if (args.orgs && args.orgs.length > 0) {
      const type = args.is_pr ? "pr" : "issue";
      const orgFilter = args.orgs.map((o) => `org:${o}`).join(" ");
      const baseQuery = `is:${type} assignee:edmundmiller is:open updated:>=2025-09-09 ${orgFilter}`;
      const query = args.is_pr
        ? `${baseQuery} -author:app/renovate -author:app/dependabot`
        : baseQuery;
      lines.push(`query = "${query}"`);
    }

    lines.push(`include_user_issues = false`);
    lines.push(`include_user_repos = false`);

    // Tags
    const tags = ["github", "assigned"];
    if (args.is_pr) tags.push("pr");
    lines.push(`add_tags = [${tags.map((t) => `"${t}"`).join(", ")}]`);

    lines.push(`default_priority = "L"`);
  } else if (args.service === "linear") {
    lines.push(
      `api_token = "@oracle:eval:cat /usr/local/var/opnix/secrets/bugwarrior-linear-token"`
    );
    lines.push(`only_if_assigned = "edmund.a.miller@gmail.com"`);
    lines.push(`status_types = ["unstarted", "started"]`);
    lines.push(`import_labels_as_tags = true`);
    lines.push(`add_tags = ["linear"]`);
    lines.push(`default_priority = "M"`);
  } else if (args.service === "applereminders") {
    lines.push(`description_template = "{{applereminderstitle}}"`);
    lines.push(`lists = ["Reminders"]`);
  }

  // Always add workspace
  lines.push(`workspace_template = "${args.workspace}"`);

  return lines.join("\n");
}

/**
 * Add a new target to the config file
 */
function addTargetToConfig(content: string, targetName: string, newSection: string): string {
  const lines = content.split("\n");

  // Find and update the targets list in [general]
  let inGeneral = false;
  let targetsLineIdx = -1;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();

    if (line === "[general]") {
      inGeneral = true;
      continue;
    }

    if (inGeneral && line.startsWith("[") && line !== "[general]") {
      inGeneral = false;
      continue;
    }

    if (inGeneral && line.startsWith("targets = [")) {
      targetsLineIdx = i;
      break;
    }
  }

  // Add target name to the list
  if (targetsLineIdx !== -1) {
    // Find the closing bracket of the targets array
    let closingIdx = targetsLineIdx;
    for (let i = targetsLineIdx; i < lines.length; i++) {
      if (lines[i].includes("]")) {
        closingIdx = i;
        break;
      }
    }

    // Insert new target before the closing bracket
    const closingLine = lines[closingIdx];
    const indent = closingLine.match(/^(\s*)/)?.[1] || "    ";

    if (closingLine.trim() === "]") {
      // Multi-line array, add before ]
      lines.splice(closingIdx, 0, `${indent}"${targetName}",`);
    } else {
      // Single or last line with ], insert before ]
      lines[closingIdx] = closingLine.replace("]", `"${targetName}",\n]`);
    }
  }

  // Append the new section at the end
  const result = lines.join("\n").trimEnd() + "\n\n" + newSection + "\n";

  return result;
}
