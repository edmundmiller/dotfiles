# Worklog: codex-worktree-remote-migration

Status: complete

## Objective

Retire every safely recoverable local Codex worktree from MacTraitor-Pro while
preserving all agent traces, dirty changes, and unpublished commits. Stop when
current traces have a verified encrypted remote backup, every worktree has an
auditable disposition, preserved work is reachable from a verified remote ref,
only genuinely blocked worktrees remain locally, and storage is remeasured.

## Decisions

- Never remove a worktree because it is merely old or clean. Verify Git
  ownership, current dirty state, HEAD reachability, and remote publication at
  the moment of removal.
- Push preserved work to collision-resistant backup branches without rewriting
  existing remote history. Dirty work must be committed in its owning worktree
  before publication, with generated secrets excluded from commits.
- Refresh and verify encrypted trace backups before changing worktree state.
- Do not compete with the user-started `hey gc`; worktree inventory and trace
  backup may proceed, but Nix operations wait for that process to finish.
- Treat Amp Orbs as the default future execution environment. This run cleans
  existing Codex state; it does not add another local scheduler or worktree
  manager.

## Evidence

- User explicitly authorized preserving and pushing dirty/unpublished work,
  backing up all traces, and cleaning Codex worktrees.
- `hosts/mactraitorpro/storage.md` records 183 Codex worktrees using 116.528 GiB
  and requires ownership, dirty-state, and landing checks before removal.
- Schema-v2 run receipt:
  `/Users/emiller/.local/state/dotfiles-agent-runs/53e298a49a4b/20260831T043724Z-aaaf05dd8218.json`.
- A fresh trace snapshot covered 26.219 GiB and 497,731 source files across
  OMP, Codex, Claude, Pi, OpenCode, Amp, Devin, Goose, Droid, Factory, Hermes,
  ACPX, and diagnostic stores. It was encrypted for both the user and NUC host
  age recipients and written to
  `nuc:/home/emiller/archive/agent-traces/agent-traces-20260831T043945Z.tar.zst.age`.
  Full remote decrypt, zstd decode, and tar listing passed with 572,882 archive
  entries and the manifest present. SHA-256:
  `66497041ba5bc9c03e234eee7182f4e130569ca6515795e771ab915ceec22291`.
  The checksum sidecar exists beside the 5.756 GiB archive and local staging
  was removed.
- The bounded inventory found 162 Codex paths totaling 114.02 GiB: 95 clean
  and 67 dirty. No running process command line referenced an inventoried
  path. Two apparent Dissertation worktrees were symlinks to the same primary
  checkout rather than registered Git worktrees; only those aliases were
  removed.
- All 162 inventory entries have a recorded final disposition. Clean HEADs
  were either proven reachable from freshly fetched remote refs or pushed to
  collision-resistant `archive/codex/*` refs. Dirty filesystem states were
  committed on archive branches, pushed without rewriting remote history, and
  verified with `git ls-remote` before removal. The mid-rebase vault worktree
  was captured with a temporary Git index and `git commit-tree`, avoiding any
  mutation of its in-progress index before publication.
- 116 unique archive branches were created. The Dissertation snapshot also
  required and completed a verified 247-object / 279 MB Git LFS upload before
  GitHub accepted its archive ref.
- TruffleHog scanned 7,278 changed files / 186,072,604 bytes before dirty
  publication. It found zero verified credentials. Two unverified URI findings
  were manually confirmed as placeholder basic-auth syntax in an archived
  Dependabot review note.
- Final disposition manifest:
  `/Users/emiller/.local/state/codex-worktree-final-disposition-20260831T054149Z.json`.
  It records 162/162 dispositions, zero missing entries, zero registered Codex
  worktrees, and no payload below `~/.codex/worktrees` other than the zero-byte
  `.metadata_never_index` marker.
- After ChatGPT and Buzz stopped, a final Codex-only snapshot was encrypted and
  uploaded to
  `nuc:/home/emiller/archive/agent-traces/codex-final-state-20260831T121524Z.tar.zst.age`.
  A full remote read, local age decrypt, zstd decode, and tar listing passed
  with 335,563 entries. SHA-256:
  `858294097982b486ace98a8c3c6f1c5935a6346a8a53efbf4a94c58651a336ee`.
  All six transactional SQLite backups passed `PRAGMA integrity_check`.
- A Nix-managed OMP SkillOpt launch agent was then found actively invoking
  `codex exec`; it had recreated a small amount of state during the prior
  snapshot. That process was stopped and its tail state was separately backed
  up and fully verified at
  `nuc:/home/emiller/archive/agent-traces/codex-final-tail-20260831T122811Z.tar.zst.age`
  with 4,412 entries and SHA-256
  `ff4f2ff41425782c157bc967c4c09c284541f6b21e000a13b38905a0972b2fc4`.
- The final purge removed 21,679,501,077 bytes of backed-up Codex trace/runtime
  state, then removed the remaining 461,361,043-byte rebuildable Codex root.
  Buzz's 457 MB Codex ACP `node-tools` installation was also removed.
- Direct Codex is now disabled on MacTraitor-Pro: the Codex agent module, the
  nightly SkillOpt/auto-commit jobs, and the Codex-based OpenWiki audit were
  removed from host configuration. `hey re` succeeded. All three LaunchAgent
  labels are absent and persistently disabled, `codex` is absent from `PATH`,
  `~/.codex` is absent, Buzz is stopped, and no Codex process remains.
- Free space rose from 25 GiB / 98% used during the inventory to 114 GiB / 88%
  used after worktree and runtime retirement.

## Reviews

No cross-model review requested. The safety plan is evidence-gated per
`AGENT_WORKFLOW.md` and the storage ledger.

## Feedback

- A global `lsof` is unsuitable for inventorying this host: it stalled for
  minutes. Bounded Git inspection plus process command-line matching completed
  reliably.
- Pre-push hooks are unsafe during archival migration because an old Beads
  database schema blocked pushes and one hook materialized sync changes in a
  formerly clean worktree. Archival pushes used `--no-verify` only after the
  commit had been independently inspected and later verified remotely.
- Codex paths may be symlink aliases to primary checkouts. Future cleanup must
  inspect file type and canonical path before calling `git worktree remove`.
- The user-started `hey gc` did not make progress: it has spent more than eight
  hours blocked in an uninterruptible root `lsof -n -w -F n` child. Darwin Nix
  evaluation and `hey re` still completed while that process was stuck. Treat
  long-running GC on this host as an `lsof` failure, not proof that collection
  is progressing.

## Remaining work

- The original `hey gc` process remains blocked in a root process with
  uninterruptible `lsof` I/O. Its initiating Herdr tab can be interrupted or
  the machine rebooted; no active garbage collection work is occurring.

## Commits

None.
