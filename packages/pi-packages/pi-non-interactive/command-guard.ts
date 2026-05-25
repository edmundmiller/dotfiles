/**
 * Command guard for non-interactive agent bash runs.
 *
 * Detects interactive commands that commonly hang in tool-driven sessions
 * and returns a block reason + safe non-interactive alternatives.
 */

export const NON_INTERACTIVE_ENV = {
  GIT_EDITOR: "true",
  GIT_SEQUENCE_EDITOR: "true",
  GIT_PAGER: "cat",
  PAGER: "cat",
  LESS: "-FX",
  BAT_PAGER: "cat",
} as const;

export type CommandBlock = {
  block: true;
  rule: string;
  reason: string;
  safeCommand?: string;
};

function hasFlag(command: string, flags: string[]): boolean {
  return flags.some((flag) => new RegExp(`(^|\\s)${flag}(=|\\s|$)`, "i").test(command));
}

function isGitCommit(command: string): boolean {
  return /\bgit\s+commit\b/i.test(command);
}

function hasCommitMessageFlag(command: string): boolean {
  return (
    hasFlag(command, ["-m", "--message", "-F", "--file", "--reuse-message", "-C"]) ||
    /(^|\s)-[a-zA-Z]*m[a-zA-Z]*(\s|$)/.test(command) ||
    /(^|\s)-[a-zA-Z]*F[a-zA-Z]*(\s|$)/.test(command)
  );
}

function hasNoEditFlag(command: string): boolean {
  return hasFlag(command, ["--no-edit"]);
}

function hasAmendFlag(command: string): boolean {
  return hasFlag(command, ["--amend"]);
}

function isDirectInteractiveEditorOrPager(command: string): boolean {
  return /(^|[;&|()]\s*)(vim|nvim|vi|nano|emacs|less|more|most|man)(?=\s|$)/.test(command.trim());
}

function isInteractiveRebase(command: string): boolean {
  return /\bgit\s+rebase\b.*\s(-i|--interactive)(\s|$)/i.test(command);
}

function isPatchAdd(command: string): boolean {
  return /\bgit\s+add\b.*\s(-p|--patch)(\s|$)/i.test(command);
}

function isInteractiveGitTool(command: string): boolean {
  return /\bgit\s+(mergetool|difftool|gui|citool)\b/i.test(command);
}

export function getSafeAlternative(command: string): string | undefined {
  const normalized = command.trim();

  if (isInteractiveRebase(normalized)) {
    return "git rebase <upstream>  # or: git commit --fixup <sha> && git rebase --autosquash <upstream>";
  }

  if (isPatchAdd(normalized)) {
    return "git hunks list && git hunks add <hunk-id>";
  }

  if (isGitCommit(normalized) && hasAmendFlag(normalized) && !hasCommitMessageFlag(normalized)) {
    return normalized.includes("--no-edit") ? normalized : `${normalized} --no-edit`;
  }

  if (isGitCommit(normalized) && !hasCommitMessageFlag(normalized) && !hasNoEditFlag(normalized)) {
    return 'git commit -m "<message>"';
  }

  if (isDirectInteractiveEditorOrPager(normalized)) {
    return "Use read/edit/write tools (or bash with non-interactive flags) instead of interactive TUI commands.";
  }

  if (isInteractiveGitTool(normalized)) {
    return "Use git merge / git diff with explicit flags, or resolve files directly with read/edit tools.";
  }

  return undefined;
}

export function shouldBlockInteractiveCommand(command: string): CommandBlock | undefined {
  const normalized = command.trim();

  const block = (rule: string, message: string): CommandBlock => {
    const safe = getSafeAlternative(normalized);
    const safeText = safe ?? "Use non-interactive flags or read/edit/write tools.";
    return {
      block: true,
      rule,
      safeCommand: safe,
      reason: `${message}\nUse instead: ${safeText}`,
    };
  };

  if (isInteractiveRebase(normalized)) {
    return block(
      "git-rebase-interactive",
      "Blocked interactive command: `git rebase -i/--interactive` can hang in non-interactive runs."
    );
  }

  if (isPatchAdd(normalized)) {
    return block(
      "git-add-patch",
      "Blocked interactive command: `git add -p/--patch` opens an interactive patch selector."
    );
  }

  if (
    isGitCommit(normalized) &&
    hasAmendFlag(normalized) &&
    !hasCommitMessageFlag(normalized) &&
    !hasNoEditFlag(normalized)
  ) {
    return block(
      "git-commit-amend-editor",
      "Blocked editor-dependent command: `git commit --amend` without message/no-edit may open an editor."
    );
  }

  if (isGitCommit(normalized) && !hasCommitMessageFlag(normalized) && !hasNoEditFlag(normalized)) {
    return block(
      "git-commit-editor",
      "Blocked editor-dependent command: `git commit` without -m/-F/--no-edit may open an editor."
    );
  }

  if (isInteractiveGitTool(normalized)) {
    return block(
      "git-interactive-tool",
      "Blocked interactive git TUI command (mergetool/difftool/gui/citool)."
    );
  }

  if (isDirectInteractiveEditorOrPager(normalized)) {
    return block(
      "interactive-editor-pager",
      "Blocked direct interactive editor/pager command. These hang in agent bash runs."
    );
  }

  return undefined;
}
