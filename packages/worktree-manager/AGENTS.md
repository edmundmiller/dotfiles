# Worktree manager

Package upstream `jarredkenny/worktree-manager` (`@jx0/wtm`) for Jmux's bare-repo
worktree flow (`C-c M` → new worktree in this setup). Bun builds ESM and the
wrapped `wtm` supplies Git on PATH. Upstream sources remain fetched, not vendored.

Package smoke check is `wtm help`; live worktree mutations are not necessary
to establish that packaging succeeds.
