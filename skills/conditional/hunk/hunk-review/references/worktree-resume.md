# Resumable worktree reviews

Hunk 0.17 records reloadable review provenance per Git worktree. `hunk resume` reopens the last source for the current worktree instead of assuming a new working-tree diff.

## When to resume

Use `hunk resume` when:

- a paired Hunk pane was closed or died;
- returning to an agent session and its associated review source;
- the prior source was a commit/show/path-limited review that should be preserved;
- a worktree-specific review should not be confused with another checkout of the same repo.

Run it from the intended worktree:

```bash
cd /path/to/worktree
hunk resume
```

If no resumable source exists, open a fresh review from the user-facing terminal. Agents must not launch the interactive TUI in their own tool terminal.

## Dotfiles paired launcher

This repository's tmux workflow pairs an agent pane with a Hunk pane and stamps both with worktree/session metadata.

- `config/tmux/open-hunk.sh --resume` executes `hunk resume` and falls back to a fresh diff only when resume support is unavailable.
- `config/tmux/worktree-agent-hunk.sh` creates or repairs the paired Hunk pane beside OMP, Pi, Hermes, or OpenCode sessions.
- `config/tmux/agent-hunk-sessions.ts` discovers resumable runtime sessions scoped to known worktrees.

When repairing a pair, preserve the canonical worktree cwd. Do not point a Hunk pane at the repository's main checkout merely because it shares Git history.

## Live session versus resume

- Use `hunk session reload` to change an already-open live window.
- Use `hunk resume` to start/restart a TUI from persisted worktree provenance.
- Use `hunk session get` to confirm what a live window currently shows.

Do not use `--session-path` or `--source` as a substitute for correct worktree pairing. Those advanced selectors intentionally separate window selection from reload execution directory and are easy to misuse.

## Verification

After resume or repair:

1. Confirm the Hunk pane is alive.
2. Run `hunk session get --repo /absolute/worktree --json` from another terminal.
3. Verify `Repo`, `Path`, and `Source` match the intended worktree and review.
4. Inspect `hunk session context` before adding comments.

A respawned pane or successful `hunk resume` exit is not enough; verify the registered live session.
