## Working defaults (from the 2026-11 usage insights)

<!-- Source: dotfiles config/claude/rules/. Deployed to ~/.claude/rules/ by modules/agents/claude. -->
<!-- The Apple rule belongs in the nextflow-apple repo guide; drop it here once it lives there. -->

Each line fixes a failure that recurred across sessions. Core instructions win on conflict.

- Blocked on me (secret, approval, permission): say it once with the exact
  action I must take, then end the turn. If a goal or Stop hook re-fires while still blocked,
  answer in one line and do not re-run the same check or repeat the status.
- Every commit is signed. If signing fails, report the error once and stop; never switch to
  unsigned commits or bypass signing.
- "Why is X broken": before fixing, check how widespread it is (one terminal, one repo, or
  everywhere), then run the cheapest check for each of your top hypotheses. No filesystem-wide
  `find` without asking.
- Prefer an authenticated CLI over a connector that is failing: `tw` for Seqera Platform,
  `gh secret set` for GitHub secrets, `gh` for PRs.
- macOS has BSD userland: edit files with the Edit tool, never `sed -i`. Probe and test scripts
  use absolute paths and `cd <dir> || exit 1`; none may run in `$HOME`. Never `mise trust --all`.
- A linked doc section is a spec: read it word for word (the vendor's docs MCP `read_doc` if any),
  not a subagent summary, and turn each stated limit into a check. Re-read linked pages before
  saying "the docs don't cover it".
- Before asking approval for a named resource, run cheap read-only checks that the action can
  succeed. If it still fails, ask again before using any substitute.
- After a state-changing request, read its status and body before polling; "unchanged since the
  request" is a terminal state.
- Check an install the way the user runs it: the bare command in a fresh login shell.
- Apple apps: after a UI change, build and run both the iOS simulator and the Desktop target
  before calling it done, and name any target you could not run. Afterwards run
  `xcrun simctl shutdown all`.
