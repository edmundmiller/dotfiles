# Worktree manager

Package upstream `jarredkenny/worktree-manager` (`@jx0/wtm`) for Jmux's bare-repo
worktree flow (`C-c M` → new worktree in this setup). Bun builds ESM and the
wrapped `wtm` supplies Git on PATH. Upstream sources remain fetched, not vendored.

Run `hey check packages/worktree-manager` and build the package after source,
dependency, or wrapper changes. Keep mutation tests in a disposable bare-repo
fixture; use `wtm help` as the smoke check for packaging-only changes.
