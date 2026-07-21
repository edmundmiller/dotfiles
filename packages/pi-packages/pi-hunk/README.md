---
purpose: Provide Pi tools for Hunk review sessions inside Herdr.
applies_to: Installing, using, or changing the pi-hunk package.
entrypoint: Use hunk_diff to open a review, then hunk_review or hunk_comments for feedback.
verification: Run bun test and bun run check in packages/pi-packages/pi-hunk.
update_when: Hunk session commands, Herdr pane APIs, or Pi tool behavior changes.
---

# pi-hunk

Pi tools for human-in-the-loop code review with [Hunk](https://github.com/ogulcancelik/hunk).

## Workflow

```text
Pi changes code → Hunk shows diff → user reviews/comments → Pi reads comments → Pi fixes → Hunk reloads
```

## Tools

- `hunk_diff` — open a Hunk diff review through Herdr's supported pane API, optionally watching changes.
- `hunk_reload` — reload the active Hunk session for the repo.
- `hunk_review` — read Hunk's session review/context, including patch and notes when requested.
- `hunk_comments` — list/apply/clear/remove Hunk comments for the repo.
- `hunk_commit` — commit reviewed changes with an explicit message, optional `git add -A`, optional push.

Most tools default to the Pi cwd as the repo anchor and use `hunk session ... --repo <cwd>` when possible.

`hunk_diff` and `hunk_reload` write `.git/hunk/last-pi-turn.json` so Hunk's Last Pi turn source can reload the last Pi-requested diff.

## Notes

`hunk_diff` requires `HERDR_ENV=1`. It creates a pane or tab first, extracts the returned live pane ID, and then runs Hunk there. This keeps the interactive UI out of Pi's tool call without relying on removed compatibility helpers.
