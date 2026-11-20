# pi-hunk

Pi tools for human-in-the-loop code review with [Hunk](https://github.com/ogulcancelik/hunk).

## Workflow

```text
Pi changes code → Hunk shows diff → user reviews/comments → Pi reads comments → Pi fixes → Hunk reloads
```

## Tools

- `hunk_reload` — reload the active Hunk session for the repo.
- `hunk_review` — read Hunk's session review/context, including patch and notes when requested.
- `hunk_comments` — list/apply/clear/remove Hunk comments for the repo.
- `hunk_commit` — commit reviewed changes with an explicit message, optional `git add -A`, optional push.

Most tools default to the Pi cwd as the repo anchor and use `hunk session ... --repo <cwd>` when possible.

`hunk_reload` writes `.git/hunk/last-pi-turn.json` for diff reloads so Hunk's Last Pi turn source can reload the last Pi-requested diff.

## Notes

The former `hunk_diff` pane launcher used the retired Herdr TUI protocol and is removed. Open Hunk in a terminal or use `herdr-dev open /path/to/checkout` for a native Herdr review tab. The remaining tools operate on Hunk sessions without a multiplexer.
