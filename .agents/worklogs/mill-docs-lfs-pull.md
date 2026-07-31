# Worklog: mill-docs-lfs-pull

Status: complete

## Objective

Stop the NUC pull timer from creating autostashes when local history violates Git LFS pointer rules. Land and deploy the guard, preserve all NUC work and stashes, repair the NUC checkout, then prove a fresh natural service run succeeds with NUC `main` equal to remote `main`.

## Decisions

- Treat `/home/emiller/mill-docs` as user-owned: no reset, clean, stash drop, or overwrite.
- Use the user-named systemd service as the regression seam.
- Keep mill-docs history repair separate from dotfiles service changes.

## Evidence

- `git lfs fsck --pointers HEAD` on the NUC reports exactly three raw PDF blobs.
- Remote mill-docs `main` stores 131-byte LFS pointers for the same SHA-256 content.
- NUC branch is 7 ahead and 421 behind; the frozen stash count is 12,582.
- Repeated timer runs create identical three-file autostashes before failing.
- `hey nuc-wt build` passed for both the expected-failure test commit and the implementation.
- `nix build --no-link .#checks.x86_64-linux.nuc-mill-docs-git-pull` passed on the NUC.
- The built script rejected the live invalid checkout before pull; stash count and tip stayed 12,582 and `694e0bf6b5c5b3f327870e129d631345600e16b1`.
- `hey agent-audit-tests` passed.
- Dotfiles `main` and `origin/main` landed at `43c1bac35dee0776af95f019314021c193866f2c`; NUC generation 1269 contains the pointer guard.
- Signed mill-docs reconciliation `9f44d66af13bad6ebbc17da4e10dcf87e843c11a` is equal on Buzz, GitHub, and NUC `main`.
- The deployed service rebased naturally, then reran up-to-date with exit 0, LFS green, and all 16 divergent/unique files restored byte-identically.
- The timer-triggered 17:31 CDT run reported `Git LFS fsck OK`, `Already up to date`, `Result=success`, and `ExecMainStatus=0`.
- NUC preservation ref `preserve/nuc-lfs-repair-20260731` retains `abdc30044bfa7c69d928aaf0de25f6ad68e38068`; all 12,582 stashes retain tip `694e0bf6b5c5b3f327870e129d631345600e16b1`.

## Reviews

- Plan and landing gates blocked: Claude, Gemini, and Pi ACP routes all returned authentication required. No review findings were available.

## Feedback

- The plan/landing reviewer routes need usable non-primary authentication or a local fallback.

## Remaining work

- None.

## Commits

- `c2f23dce2` test(nuc): cover LFS pointer preflight
- `66dbe712f` fix(nuc): reject invalid LFS history before pull
- `43c1bac35` docs(agent): record mill-docs pull repair
- `9f44d66af` chore(sync): reconcile NUC history after LFS repair (mill-docs)
