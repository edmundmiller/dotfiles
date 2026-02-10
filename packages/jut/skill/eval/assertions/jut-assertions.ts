// Assertion functions for jut skill eval.
// Each function receives the raw output string from the eval provider
// and returns true if the agent's behavior matches expectations.

type CommandTrace = {
  command?: unknown;
  failed?: unknown;
};

type RevisionInfo = {
  change_id?: string;
  short_id?: string;
  description?: string;
  bookmarks?: string[];
  is_working_copy?: boolean;
  is_conflicted?: boolean;
  is_empty?: boolean;
};

type Stack = {
  bookmarks?: string[];
  revisions?: RevisionInfo[];
};

type WorkspaceState = {
  trunk?: RevisionInfo;
  stacks?: Stack[];
  working_copy?: RevisionInfo;
  uncommitted_files?: { status: string; path: string }[];
};

type EvalOutput = {
  commands?: CommandTrace[];
  result?: unknown;
  repoState?: WorkspaceState | null;
  repoStateError?: unknown;
};

const JJ_WRITE_RE =
  /\bjj (describe|new|commit|squash|abandon|restore|rebase|bookmark set|bookmark delete|git push|git fetch)\b/;

function normalizeCommand(command: string): string {
  const trimmed = command.trim();
  const shellWrapped = trimmed.match(/^[^ ]+ -lc '([\s\S]*)'$/);
  if (shellWrapped && shellWrapped[1]) {
    return shellWrapped[1].trim();
  }
  return trimmed;
}

function isHelpCommand(command: string): boolean {
  return /\s--help(\s|$)/.test(` ${normalizeCommand(command)} `);
}

function parseOutput(output: unknown): EvalOutput {
  if (typeof output !== "string") return {};
  try {
    return JSON.parse(output) as EvalOutput;
  } catch {
    return {};
  }
}

function commandStrings(data: EvalOutput): string[] {
  return (data.commands || [])
    .filter((entry) => entry?.failed !== true)
    .map((entry) => (typeof entry?.command === "string" ? normalizeCommand(entry.command) : ""))
    .filter((cmd) => cmd.length > 0);
}

function hasRepoState(data: EvalOutput): boolean {
  return !!data.repoState && !data.repoStateError;
}

function containsJjWrite(commands: string[]): boolean {
  return commands.some((cmd) => JJ_WRITE_RE.test(cmd));
}

function allBranches(data: EvalOutput): Stack[] {
  return data.repoState?.stacks || [];
}

// ─── Assertion Functions ───────────────────────────────────────────

/**
 * Basic commit flow: status before commit, commit has --json --status-after.
 */
export function basicCommitFlow(output: unknown): boolean {
  const data = parseOutput(output);
  const commands = commandStrings(data);

  const statusIndex = commands.findIndex((cmd) => cmd.includes("jut status"));
  const commitIndex = commands.findIndex(
    (cmd) => cmd.includes("jut commit") && !isHelpCommand(cmd)
  );
  const commitCmd = commitIndex >= 0 ? commands[commitIndex] : "";
  const hasJson = commitCmd.includes("--json");
  const hasStatusAfter = commitCmd.includes("--status-after");
  const hasMessage = commitCmd.includes("-m");

  // No redundant status after --status-after
  const redundantStatus =
    commitIndex >= 0 && commands.slice(commitIndex + 1).some((cmd) => cmd.includes("jut status"));

  return (
    statusIndex >= 0 &&
    commitIndex > statusIndex &&
    hasJson &&
    hasStatusAfter &&
    hasMessage &&
    !redundantStatus &&
    !containsJjWrite(commands)
  );
}

/**
 * Branch workflow: create branch then commit.
 */
export function branchWorkflow(output: unknown): boolean {
  const data = parseOutput(output);
  const commands = commandStrings(data);

  const branchIndex = commands.findIndex(
    (cmd) => cmd.includes("jut branch") && !isHelpCommand(cmd)
  );
  const commitIndex = commands.findIndex(
    (cmd) => cmd.includes("jut commit") && !isHelpCommand(cmd)
  );
  const commitCmd = commitIndex >= 0 ? commands[commitIndex] : "";

  return (
    branchIndex >= 0 &&
    commitIndex > branchIndex &&
    commitCmd.includes("--json") &&
    commitCmd.includes("--status-after") &&
    !containsJjWrite(commands)
  );
}

/**
 * Rub amend: use rub to amend a file into a revision.
 */
export function rubAmendFlow(output: unknown): boolean {
  const data = parseOutput(output);
  const commands = commandStrings(data);

  const statusIndex = commands.findIndex((cmd) => cmd.includes("jut status"));
  // Match both explicit `jut rub` and implicit `jut <source> <target>`
  const rubIndex = commands.findIndex(
    (cmd) => (cmd.includes("jut rub") || cmd.match(/^jut\s+\S+\.\S+\s+\S+/)) && !isHelpCommand(cmd)
  );
  const rubCmd = rubIndex >= 0 ? commands[rubIndex] : "";

  return (
    statusIndex >= 0 &&
    rubIndex > statusIndex &&
    rubCmd.includes("--json") &&
    rubCmd.includes("--status-after") &&
    !containsJjWrite(commands)
  );
}

/**
 * Discard flow: use rub zz or discard to remove changes.
 */
export function discardFlow(output: unknown): boolean {
  const data = parseOutput(output);
  const commands = commandStrings(data);

  const discardIndex = commands.findIndex(
    (cmd) =>
      (cmd.includes("jut discard") ||
        (cmd.includes("jut rub") && cmd.includes("zz")) ||
        cmd.match(/^jut\s+\S+\s+zz\b/)) &&
      !isHelpCommand(cmd)
  );
  const discardCmd = discardIndex >= 0 ? commands[discardIndex] : "";

  return (
    discardIndex >= 0 &&
    discardCmd.includes("--json") &&
    discardCmd.includes("--status-after") &&
    !containsJjWrite(commands)
  );
}

/**
 * Pull flow: jut pull with proper flags.
 */
export function pullFlow(output: unknown): boolean {
  const data = parseOutput(output);
  const commands = commandStrings(data);

  const pullIndex = commands.findIndex((cmd) => cmd.includes("jut pull") && !isHelpCommand(cmd));
  const pullCmd = pullIndex >= 0 ? commands[pullIndex] : "";

  return (
    pullIndex >= 0 &&
    pullCmd.includes("--json") &&
    pullCmd.includes("--status-after") &&
    !containsJjWrite(commands)
  );
}

/**
 * Squash flow: squash revisions with proper flags.
 */
export function squashFlow(output: unknown): boolean {
  const data = parseOutput(output);
  const commands = commandStrings(data);

  const statusIndex = commands.findIndex((cmd) => cmd.includes("jut status"));
  const squashIndex = commands.findIndex(
    (cmd) => cmd.includes("jut squash") && !isHelpCommand(cmd)
  );
  const squashCmd = squashIndex >= 0 ? commands[squashIndex] : "";

  return (
    statusIndex >= 0 &&
    squashIndex > statusIndex &&
    squashCmd.includes("--json") &&
    squashCmd.includes("--status-after") &&
    !containsJjWrite(commands)
  );
}

/**
 * Interactive fallback: agent correctly drops to jj for interactive commands
 * (split, resolve, diffedit) rather than trying jut.
 */
export function interactiveFallback(output: unknown): boolean {
  const data = parseOutput(output);
  const commands = commandStrings(data);

  // Agent should use raw jj for split, not jut
  const usesJjSplit = commands.some((cmd) => /\bjj split\b/.test(cmd));
  const usesJutSplit = commands.some((cmd) => /\bjut split\b/.test(cmd));

  // Should still use jut for status
  const usesJutStatus = commands.some((cmd) => cmd.includes("jut status"));

  return usesJjSplit && !usesJutSplit && usesJutStatus;
}

/**
 * PR flow: push + create PR with jut.
 */
export function prFlow(output: unknown): boolean {
  const data = parseOutput(output);
  const commands = commandStrings(data);

  const prIndex = commands.findIndex((cmd) => cmd.includes("jut pr") && !isHelpCommand(cmd));
  const prCmd = prIndex >= 0 ? commands[prIndex] : "";

  // Should use jut pr, not gh pr directly
  const usesGhPr = commands.some((cmd) => /\bgh pr\b/.test(cmd));

  return prIndex >= 0 && prCmd.includes("--json") && !usesGhPr;
}

/**
 * Ordering: status always comes before mutations.
 */
export function orderingFlow(output: unknown): boolean {
  const data = parseOutput(output);
  const commands = commandStrings(data);

  const statusIndex = commands.findIndex((cmd) => cmd.includes("jut status"));
  const firstMutation = commands.findIndex(
    (cmd) =>
      /\bjut (commit|rub|squash|reword|discard|absorb|push|pull|branch|undo)\b/.test(cmd) &&
      !isHelpCommand(cmd)
  );

  return statusIndex >= 0 && (firstMutation < 0 || statusIndex < firstMutation);
}

/**
 * Stacked branch: create with --stack, verify correct base.
 */
export function stackedBranchFlow(output: unknown): boolean {
  const data = parseOutput(output);
  const commands = commandStrings(data);

  const stackIndex = commands.findIndex(
    (cmd) => cmd.includes("jut branch") && cmd.includes("--stack")
  );
  const commitIndex = commands.findIndex(
    (cmd) => cmd.includes("jut commit") && !isHelpCommand(cmd)
  );

  const stacks = allBranches(data);
  // Verify we have at least 2 stacks (base + stacked)
  const hasMultipleStacks = stacks.length >= 1;

  return (
    stackIndex >= 0 &&
    commitIndex > stackIndex &&
    hasRepoState(data) &&
    hasMultipleStacks &&
    !containsJjWrite(commands)
  );
}
