---
name: hunk-review
description: Review and steer live Hunk diff sessions, inspect focused files/hunks, navigate, reload sources, resume worktree reviews, and add validated inline comments. Use when the user has Hunk open, asks for an interactive diff review, mentions Hunk comments, or wants to resume a paired agent/Hunk worktree.
---

# Hunk Review

Treat Hunk as the user's interactive review UI. Never launch an interactive `hunk diff` or `hunk show` inside the agent terminal. Inspect and control an existing session through structured resources or `hunk session …`.

## Choose the control path

1. **Harness resources:** When `hunk://` reads are supported, prefer `hunk://review?repo=…`, `hunk://context?repo=…`, and `hunk://comments?repo=…`. Read `hunk://review` first; request raw patch content only for files that need close review.
2. **Session CLI:** Use `hunk session list|get|review|context|navigate|reload|comment` when internal resources are unavailable or mutation is required.
3. **Resumable worktree UI:** Use `hunk resume` or this repo's paired launcher to reopen the last source associated with a Git worktree.
4. **Agent context file:** Use `--agent-context` only when notes already exist as a sidecar and no live session should be steered.

Read `references/live-review.md` for the complete workflow and `references/worktree-resume.md` for paired worktree behavior.

## Start with structure

```bash
hunk session list --json
hunk session get --repo . --json
hunk session review --repo . --json
```

Confirm session path, repo, and loaded source before commenting. Start without raw patch text. Add `--include-patch` only when the structured file/hunk inventory is insufficient.

If multiple sessions match, select the exact session ID. Never guess from current cwd alone when multiple worktrees or Hunk windows are open.

## Review in story order

1. Inspect all changed files and hunks.
2. Identify correctness, security, data-loss, and maintainability findings.
3. Navigate the live UI to the first important location.
4. Add only findings the user would benefit from revisiting inline.
5. Batch several prepared comments in one validated operation.
6. Re-read comments and current context to verify the user-visible result.

```bash
hunk session navigate --repo . --file src/App.tsx --hunk 2
hunk session comment add --repo . --file src/App.tsx --new-line 72 --summary "Handle the rejected request"
hunk session comment list --repo . --type agent
```

Do not comment on every hunk. Keep summaries specific and actionable; put explanation in the comment text only when the installed Hunk version supports it.

## Apply comment batches safely

Prepare a JSON file, validate it, then apply it:

```bash
python3 ~/.agents/skills/hunk-review/scripts/apply_comments.py --check comments.json
python3 ~/.agents/skills/hunk-review/scripts/apply_comments.py --repo . comments.json
```

The helper validates the whole payload before invoking Hunk and avoids shell-quoting failures. Hunk also validates the full stdin batch before mutation.

## Reload and resume deliberately

Reload changes the source shown by an already-open window:

```bash
hunk session reload --repo . -- diff
hunk session reload --repo . -- show HEAD~1 -- README.md
```

Always include `--` before the nested Hunk command. Prefer `--repo <worktree>` for normal worktree sessions. Use `--session-path` and `--source` only when intentionally repointing a live window.

`hunk resume` is different: it reopens the last reloadable source recorded for the current Git worktree. Use it for paired agent/review layouts and after a Hunk pane is respawned.

## Verify mutations

A successful command is not enough. After adding, removing, clearing, reloading, or navigating:

- Re-read `hunk://comments` / `hunk://context`, or
- Run `hunk session comment list` / `hunk session context`.

Verify the intended file, side, and line are visible. New-line and old-line targets are not interchangeable.

## Recovery

- **No active sessions:** If Hunk is visibly open, suspect loopback sandboxing and retry with network permission. Otherwise ask the user to open Hunk.
- **Multiple matches:** Pass the exact session ID.
- **No visible diff file:** Inspect context and loaded source; reload only if the review truly targets another source.
- **Wrong worktree:** Compare session `Repo`, session `Path`, and current worktree before using advanced selectors.
- **Batch rejected:** Fix every payload item; Hunk makes no partial mutation.
- **Untracked noise:** Reload `diff --exclude-untracked` only when the user requested tracked changes only.
- **Stale CLI example:** Check installed `hunk --version` and `hunk session --help`; this skill targets the deployed CLI, not unreleased `main` docs.

## Bundled resources

- `references/live-review.md` — session selection, structured inspection, navigation, comments, and verification.
- `references/worktree-resume.md` — `hunk resume`, paired agent panes, and repo-specific launchers.
- `scripts/apply_comments.py` — validates and applies comment batches from a file.
