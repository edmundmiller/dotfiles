# Worklog: nuc-mill-docs-git-pull-repair

Status: complete

## Objective

Keep `mill-docs-git-pull.service` healthy without mutating an already-unmerged checkout. Done when a regression test proves the pull script exits successfully before fetch/pull on unmerged index entries, the NUC build and dry activation pass, the conflicted checkout has an atomic preservation snapshot, and live service readback confirms a safe skip while all existing Git state remains unchanged.

## Decisions

- Preserve `/home/emiller/mill-docs` exactly; do not resolve, add, remove, clean, abort, pop/drop the stash, or pull.
- Guard only tracked unmerged index entries before network or LFS work. Leave the existing clean-checkout pull path unchanged.
- Keep the coding-agent repair in `mill-docs`; this dotfiles change owns only the host service guard.

## Evidence

- Live audit: 633 status paths, nine stage-1+2 conflicts, stash `8592173b73cce254f092ef67d0819f3247f21fa0`, no active merge/rebase marker.
- Historical journal: `git pull --rebase --autostash` fast-forwarded, then autostash replay conflicted on 2026-08-17.
- Source baseline: started from `c9fe8fd8be8c618a7e08546190f90c73d41dc52a`, then rebased without conflict onto `origin/main@c63fbd6cd6e585d5939a683d38c3aa90eac1de26` after the deployment guard rejected the stale base.
- Red check: `nuc-mill-docs-git-pull` failed with `must skip an unmerged index before fetch` against a stage-1+2 fixture.
- Second red check: the rendered service-level harness failed because a conflict skip reported healthcheck success and a conflict injected after fetch still reached pull.
- Green checks: the dedicated Nix check now covers clean success, existing conflict, post-fetch conflict preservation, and corrupt-index error propagation; `hey nuc-wt build`, `hey nuc-wt dry-activate`, `hey agent-audit-tests`, and `hey agent-finish` passed after the rebase.
- Preservation: ZFS snapshot `zroot/user/home/emiller@codex-mill-docs-git-pull-20260826T190254Z` plus matching HEAD, remote-tracking ref, ORIG_HEAD, stash, conflict-stage hash, staged patch, status hash, and worktree hash. The live index binary's stat-cache bytes changed, while all index entries and the staged patch remained identical to the atomic snapshot.
- Deployment: final production generation `/nix/store/as4hifr89fg4f9k8yzp3rjf4c4g4vs1k-nixos-system-nuc-26.11.20260714.18b9261`.
- Live oneshot at `2026-08-26 14:25:10 CDT`: `Result=success`, `ExecMainStatus=0`, `NRestarts=0`; journal reported the same nine conflicts and skipped before fetch.
- Healthchecks readback: `NUC mill-docs git pull`, `status=down`, `last_ping=2026-08-26T19:25:11+00:00`, proving the successful systemd skip was reported externally as a conflict failure.
- Post-run preservation: HEAD `4e9f7782`, remote-tracking ref `e1ab177d`, ORIG_HEAD `c18794ce`, stash `8592173b`, nine conflicts, stage hash `98593e97`, cached patch hash `37c21cf6`, status hash `20001a03`, and worktree patch hash `31f226c1` all matched the immediately pre-run values.
- Landing: the eight-revision task series was replayed onto concurrent `origin/main@ad8c51da3` in an isolated clone; all source revisions verified patch-equivalent and authoritative `origin/main` read back as `bcea095040c4cbbbac3d0ca9bcf4e088339b7f7f`.

## Reviews

- Automated plan gate attempted with `hey agent-review plan --active-model-family openai`; ACP session creation returned `RUNTIME: Authentication required`. The user explicitly authorized the bounded live repair, so implementation proceeds with that exact reviewer-access blocker recorded.
- Automated landing review attempted with `hey agent-review landing --active-model-family openai`; ACP session creation returned the same `RUNTIME: Authentication required` blocker. Local semantic diff review, dedicated Nix behavior coverage, dry activation, deployment, and live state hashes provide the available review evidence.
- Independent review found the initial helper-only test, successful conflict healthcheck, and post-fetch race window incomplete. The repair added a rendered service harness, `/fail` routing with systemd success, a final pre-pull recheck, and no-pager diagnostics.
- Follow-up review found clean-path and post-fetch preservation coverage missing and the manual-writer race undocumented. The test now asserts clean fetch/pull success and byte-equivalent semantic state after an injected conflict; `hosts/nuc/AGENTS.md` records the healthcheck distinction and residual TOCTOU boundary.
- Final bounded review found no P0-P2 defects after those remediations; rendered-script fakes and the documented lack of a shared manual-writer lock remain non-blocking limitations.

## Feedback

- The service checked operation markers but not unmerged index entries, allowing an autostash conflict to become a permanent five-minute failure loop. A service-specific lock cannot serialize uncoordinated manual Git writers, so the durable boundary is two explicit checks plus Git's own refusal to pull an unmerged index.

## Remaining work

- None.

## Commits

- `2506959de` — expected-failure regression for an unmerged index.
- `170586f98` — pre-fetch unmerged-index guard and green regression.
- `db54c4653` — recovery documentation.
- `ec526a658` — expected-failure rendered-service regression.
- `d20afc91b` — external failure routing and final pre-pull recheck.
- `37093e9cf` — clean-path and post-fetch preservation coverage.
- `215175b8a` — healthcheck and manual-writer race documentation.
