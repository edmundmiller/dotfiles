# pi-hunk

Pi tools for human-in-the-loop code review with [Hunk](https://github.com/ogulcancelik/hunk).

## Workflow

```text
Pi changes code → Hunk shows diff → user reviews/comments → Pi reads comments → Pi fixes → Hunk reloads
```

## Tools

- `hunk_diff` — open a Hunk diff review in Herdr via `herdr-hunk`, optionally watching changes.
- `hunk_reload` — reload the active Hunk session for the repo.
- `hunk_review` — read Hunk's session review/context, including patch and notes when requested.
- `hunk_comments` — list/apply/clear/remove Hunk comments for the repo.

Most tools default to the Pi cwd as the repo anchor and use `hunk session ... --repo <cwd>` when possible.

## Notes

`hunk_diff` intentionally delegates to the existing `herdr-hunk` helper instead of running `hunk diff` directly, because the Hunk diff UI is interactive and should live in its own Herdr pane/tab rather than block Pi's tool call.
