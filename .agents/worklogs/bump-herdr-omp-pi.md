# Worklog: bump-herdr-omp-pi

Status: complete

## Objective

Update the pinned Herdr and llm-agents sources to the settled upstream
revisions, refresh the affected patch stacks and dependency hashes, verify the
Linux package surfaces, and leave separate commits on the requested branch.
Stop after the requested package checks and commit creation; do not push or
create a pull request.

## Decisions

- Use a single-user Nix installation if the daemon installer cannot complete.
- Keep the llm-agents lockfile update limited to `nix flake update llm-agents`.
- Treat patch application against clean upstream checkouts as the source of
  truth for retaining, rebasing, or dropping local patches.

## Evidence

Initial checkout was clean on `main`; work continues on the requested
timestamped branch.

- Nix 2.35.2 was installed single-user with `nix-command` and `flakes`
  enabled; sandboxing was disabled to avoid the single-user store permission
  warning.
- Herdr was updated to
  `3667151744e379ac5c8f76d57203b675de8a6ebc` with source hash
  `sha256-ODwlj4ghPMh/Yfe2uuFwXEgi7NNTyHNicMrqsH7jE6I=`.
- OMP/Pi were updated through llm-agents revision
  `014bafdb20823af70eb7050bdb30fd2bdde7ffd7`; resulting versions are OMP
  `17.3.5` and Pi `0.84.2`.
- OMP's patched Cargo vendor hash is
  `sha256-2S9ZiJ9QTMp2Hxysi1NX2BLycZ306XMpEI1OovUR1PQ=`.
- All retained Herdr and OMP patches passed `git apply --check` from fresh,
  clean upstream checkouts at the target revisions.
- The overlaid Herdr package built successfully on Linux as
  `herdr-0.8.1`, and the overlaid OMP package built successfully as
  `omp-17.3.5`.
- `pkg-check` was not run: the `nix develop` shell stalled materializing a
  very large cross-platform closure.
- No Darwin configuration was evaluated.

## Reviews

None.

## Feedback

The VM initially has no `/nix` installation and direnv reports the repository
`.envrc` as blocked; package commands will use the explicit Nix environment
until Nix is installed and configured.

## Remaining work

None.

## Commits

One-intent commits on the requested branch: Herdr bump, llm-agents input bump,
OMP overlay patch/hash refresh, and a follow-up restoring the `github` lock
type for the `llm-agents` node.
