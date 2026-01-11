#!/usr/bin/env -S deno run --allow-all
/**
 * Enhanced Git-to-JJ Command Translator
 *
 * Improvements over Python version:
 * - Full argument parsing (handles flags, options, subcommands)
 * - Context-aware suggestions based on JJ state
 * - Command classification (read-only, helpers, destructive)
 * - Better error messages with examples
 */

interface ParsedCommand {
  executable: string;
  subcommand: string;
  flags: Map<string, string | boolean>;
  positional: string[];
  workdir?: string;
}

interface JJState {
  currentRevision: {
    changeId: string;
    description: string | null;
    isEmpty: boolean;
  };
  hasChanges: boolean;
}

enum CommandCategory {
  READONLY = 'readonly',
  HELPER = 'helper',
  DESTRUCTIVE = 'destructive',
}

// Command classification
const READONLY_COMMANDS = new Set([
  'status', 'st', 'log', 'show', 'diff', 'blame', 'branch',
  'remote', 'config', 'rev-parse', 'describe',
]);

const DESTRUCTIVE_COMMANDS = new Set([
  'reset --hard', 'clean', 'filter-branch', 'push --force',
]);

/**
 * Parse git command into structured components
 * Based on git-policy.ts parsing logic
 */
function parseGitCommand(cmdString: string): ParsedCommand | null {
  const parts = cmdString.trim().split(/\s+/);

  // Find git executable
  const gitIndex = parts.findIndex(p => p === 'git' || p.endsWith('/git'));
  if (gitIndex === -1) {
    return null;
  }

  const result: ParsedCommand = {
    executable: 'git',
    subcommand: '',
    flags: new Map(),
    positional: [],
  };

  let i = gitIndex + 1;
  let foundSubcommand = false;

  // Parse arguments similar to findGitSubcommand in git-policy.ts
  while (i < parts.length) {
    const arg = parts[i];

    // Handle -C workdir flag
    if (arg === '-C' && i + 1 < parts.length) {
      result.workdir = parts[i + 1];
      i += 2;
      continue;
    }

    // Handle flags with values
    if (arg.startsWith('-') && !foundSubcommand) {
      if (arg.startsWith('--')) {
        // Long flag
        const [key, value] = arg.substring(2).split('=');
        result.flags.set(key, value || true);
      } else {
        // Short flag
        result.flags.set(arg.substring(1), true);
      }
      i++;
      continue;
    }

    // First non-flag is the subcommand
    if (!foundSubcommand && !arg.startsWith('-')) {
      result.subcommand = arg;
      foundSubcommand = true;
      i++;
      continue;
    }

    // Stop at --
    if (arg === '--') {
      i++;
      break;
    }

    // After subcommand, collect positional args
    if (foundSubcommand) {
      result.positional.push(arg);
    }

    i++;
  }

  // Collect remaining as positional
  while (i < parts.length) {
    result.positional.push(parts[i++]);
  }

  return result;
}

/**
 * Classify git command by category
 */
function classifyCommand(parsed: ParsedCommand): CommandCategory {
  const cmd = parsed.subcommand;

  // Check for destructive flags
  if (
    parsed.flags.has('force') ||
    parsed.flags.has('f') ||
    (cmd === 'reset' && parsed.flags.has('hard'))
  ) {
    return CommandCategory.DESTRUCTIVE;
  }

  // Destructive commands
  if (DESTRUCTIVE_COMMANDS.has(cmd)) {
    return CommandCategory.DESTRUCTIVE;
  }

  // Read-only commands
  if (READONLY_COMMANDS.has(cmd)) {
    return CommandCategory.READONLY;
  }

  // Default to helper (needs translation)
  return CommandCategory.HELPER;
}

/**
 * Get JJ state for context-aware suggestions
 */
async function getJJState(): Promise<JJState | null> {
  try {
    // Get current revision info
    const descCmd = new Deno.Command('jj', {
      args: ['log', '-r', '@', '--no-graph', '-T', 'if(description, "has", "none")'],
      stdout: 'piped',
      stderr: 'null',
    });

    const emptyCmd = new Deno.Command('jj', {
      args: ['log', '-r', '@', '--no-graph', '-T', 'if(empty, "empty", "has_changes")'],
      stdout: 'piped',
      stderr: 'null',
    });

    const changeIdCmd = new Deno.Command('jj', {
      args: ['log', '-r', '@', '--no-graph', '-T', 'change_id.short()'],
      stdout: 'piped',
      stderr: 'null',
    });

    const [descOutput, emptyOutput, changeIdOutput] = await Promise.all([
      descCmd.output(),
      emptyCmd.output(),
      changeIdCmd.output(),
    ]);

    const hasDescription = new TextDecoder().decode(descOutput.stdout).trim() === 'has';
    const isEmpty = new TextDecoder().decode(emptyOutput.stdout).trim() === 'empty';
    const changeId = new TextDecoder().decode(changeIdOutput.stdout).trim();

    // Check for working copy changes
    const statusCmd = new Deno.Command('jj', {
      args: ['status'],
      stdout: 'piped',
      stderr: 'null',
    });

    const statusOutput = await statusCmd.output();
    const status = new TextDecoder().decode(statusOutput.stdout);
    const hasChanges = status.includes('Working copy changes:');

    return {
      currentRevision: {
        changeId,
        description: hasDescription ? 'present' : null,
        isEmpty,
      },
      hasChanges,
    };
  } catch {
    return null;
  }
}

/**
 * Translate git command to jj with context awareness
 */
async function translateToJJ(parsed: ParsedCommand): Promise<string> {
  const state = await getJJState();

  const cmd = parsed.subcommand;
  const msgFlag = parsed.flags.get('m') || parsed.flags.get('message');

  switch (cmd) {
    case 'commit': {
      if (!state) {
        return 'jj describe';
      }

      // Context-aware suggestion
      if (state.currentRevision.description && !state.currentRevision.isEmpty) {
        // Already has description and changes - suggest new commit
        return msgFlag ? `jj new -m "${msgFlag}"` : 'jj new';
      } else if (state.hasChanges || !state.currentRevision.isEmpty) {
        // Has changes but no description - describe current
        return msgFlag ? `jj describe -m "${msgFlag}"` : 'jj describe';
      } else {
        // Empty commit, no changes - need work first
        return 'jj describe  # Make changes first, then describe them';
      }
    }

    case 'add': {
      if (!state) {
        return 'jj squash';
      }

      // In jj, there's no staging area
      if (state.currentRevision.description) {
        return 'jj squash  # Move changes into described commit';
      } else {
        return 'jj describe  # Describe changes instead of staging';
      }
    }

    case 'checkout':
    case 'switch':
      return 'jj new  # Create new working copy revision';

    case 'branch':
      if (parsed.positional.length === 0 || parsed.flags.has('a')) {
        return 'jj bookmark list';
      } else {
        const branchName = parsed.positional[0];
        return `jj bookmark create ${branchName}`;
      }

    case 'push': {
      const forceFlag = parsed.flags.has('force') || parsed.flags.has('f');
      return forceFlag ? 'jj git push --force' : 'jj git push';
    }

    case 'pull':
    case 'fetch':
      return 'jj git fetch';

    case 'merge':
      return 'jj rebase  # jj uses rebase instead of merge';

    case 'rebase': {
      const interactive = parsed.flags.has('i') || parsed.flags.has('interactive');
      return interactive
        ? 'jj rebase  # Use jj edit/split/squash for interactive history editing'
        : 'jj rebase';
    }

    case 'reset': {
      const hard = parsed.flags.has('hard');
      if (hard) {
        return 'jj abandon @  # Or use jj restore to selectively restore files';
      }
      return 'jj restore';
    }

    case 'stash':
      return 'jj new  # Create new revision (no stash needed in jj)';

    case 'cherry-pick':
      return 'jj rebase -r <revision> -d <destination>';

    case 'log': {
      const oneline = parsed.flags.has('oneline');
      return oneline ? 'jj log --no-graph' : 'jj log';
    }

    default:
      return `jj ${cmd}  # Check jj docs for equivalent`;
  }
}

/**
 * Main hook logic
 */
async function main() {
  try {
    // Read event data from stdin
    const input = await Deno.readAll(Deno.stdin);
    const eventData = JSON.parse(new TextDecoder().decode(input));

    // Extract tool information
    const tool = eventData.tool || {};
    const toolName = tool.name || '';

    // Only intercept Bash tools
    if (toolName !== 'Bash') {
      console.log(JSON.stringify({ continue: true }));
      return;
    }

    // Get the command
    const params = tool.params || {};
    const command = params.command || '';

    // Parse git command
    const parsed = parseGitCommand(command);

    if (!parsed) {
      // Not a git command
      console.log(JSON.stringify({ continue: true }));
      return;
    }

    // Classify command
    const category = classifyCommand(parsed);

    // Allow read-only commands
    if (category === CommandCategory.READONLY) {
      console.log(JSON.stringify({ continue: true }));
      return;
    }

    // Block and suggest for other commands
    const jjEquivalent = await translateToJJ(parsed);

    const message = category === CommandCategory.DESTRUCTIVE
      ? `🚨 **Destructive git command blocked**

The command \`${command}\` is destructive and was blocked.

**Suggested jj equivalent:**
\`\`\`bash
${jjEquivalent}
\`\`\`

**⚠️  Warning**: This operation modifies history. Make sure you understand what you're doing.

**Safety tip**: Use \`jj op log\` to see operations and \`jj undo\` if you make a mistake.
`
      : `🚫 **Git command blocked in jj repository**

The command \`${command}\` was blocked because this is a jj repository.

**Suggested jj equivalent:**
\`\`\`bash
${jjEquivalent}
\`\`\`

**Why?** Jujutsu (jj) provides a more intuitive workflow. Mixing git and jj commands can cause confusion.

**Need help?** Use \`/jj:commit\`, \`/jj:split\`, or \`/jj:squash\` for common workflows.
`;

    console.log(JSON.stringify({
      continue: false,
      system_message: message,
    }));
  } catch (error) {
    // Fail open on errors
    console.log(JSON.stringify({
      continue: true,
      system_message: `Git-to-jj translator error: ${error.message}`,
    }));
  }
}

// Run if this is the main module
if (import.meta.main) {
  main().catch(console.error);
}

// Export for testing
export {
  parseGitCommand,
  classifyCommand,
  translateToJJ,
  type ParsedCommand,
  type JJState,
  CommandCategory,
};
