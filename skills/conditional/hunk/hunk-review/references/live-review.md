# Live Hunk review

This reference matches the deployed Hunk 0.17 session API. Verify future versions with `hunk session --help`.

## Inspect without flooding context

Prefer harness resources when available:

```text
hunk://review?repo=/absolute/repo/path
hunk://context?repo=/absolute/repo/path
hunk://comments?repo=/absolute/repo/path
```

CLI equivalent:

```bash
hunk session list --json
hunk session get --repo . --json
hunk session review --repo . --json
```

Request `--include-patch` only after the file/hunk inventory identifies what needs raw text. Use normal code-reading tools for surrounding source and symbol relationships; a diff alone may hide contracts and call sites.

## Session selectors

- `--repo <path>`: preferred; matches the loaded repository root.
- `<session-id>`: use when several windows share a repo.
- `--session-path <path>`: advanced reload selector for the live window's path.
- `--source <path>`: advanced reload execution directory; does not select the window.

Confirm `Repo`, `Path`, and `Source` with `session get` before advanced reloads.

## Navigation

Absolute navigation requires `--file` and exactly one target:

```bash
hunk session navigate --repo . --file src/App.tsx --hunk 2
hunk session navigate --repo . --file src/App.tsx --new-line 372
hunk session navigate --repo . --file src/App.tsx --old-line 355
```

Comment navigation is relative and needs no file:

```bash
hunk session navigate --repo . --next-comment
hunk session navigate --repo . --prev-comment
```

Hunk numbers and line numbers are 1-based.

## Comments

One comment:

```bash
hunk session comment add --repo . \
  --file README.md --new-line 103 \
  --summary "State the recovery command"
```

Batch comments:

```bash
python3 ~/.agents/skills/hunk-review/scripts/apply_comments.py --check comments.json
python3 ~/.agents/skills/hunk-review/scripts/apply_comments.py --repo . comments.json
```

Inspect and clean up:

```bash
hunk session comment list --repo . --type agent
hunk session comment list --repo . --type user
hunk session comment rm --repo . <comment-id>
hunk session comment clear --repo . --yes
hunk session comment clear --repo . --include-user --yes
```

Agents cannot create human-authored `c` notes. Clearing human notes is destructive; do it only when requested.

## Reload

```bash
hunk session reload --repo . -- diff
hunk session reload --repo . -- diff main...feature -- src/ui
hunk session reload --repo . -- show HEAD~1 -- README.md
```

Always retain the `--` separator before `diff` or `show`.

## Review quality

- Trace each finding into surrounding source before commenting.
- Prioritize correctness, security, data loss, misleading tests, and maintainability risks.
- Avoid style commentary already enforced by formatters.
- Avoid duplicate comments on the same root cause.
- Re-read comments after mutation to verify file, line side, and summary.
- Summarize clean reviews explicitly; do not invent a comment to prove the tool ran.
