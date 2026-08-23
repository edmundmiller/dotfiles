# Worklog: scintillate-smart-routing

Status: active

## Objective

Deploy Scintillate with Terra medium as the default route and Luna xhigh with priority service for inputs of at most 100 characters and 8 words. Stop only after the canonical source, NUC package/config, route decisions, usage telemetry, and unaffected sibling profiles are verified live.

## Decisions

- Keep both routes on `openai-codex`; Hermes records subscription usage as included, so monitor API calls and token volume rather than inventing billed dollar cost.
- Preserve the guarded gateway restart and restart only Scintillate after proving no user turn is active.
- Keep the private `agents-workspace` input on the existing `github:` fetcher so the NUC's root-owned `nix-private-github` credential remains the sole deployment authentication path.

## Evidence

- Agents-workspace red/green commits landed as `4bb2386` and `b32b054` patch-equivalent changes on remote `main` at `f8ebd6046fb04d60427b2335ce6d921122ccc532`.
- Exact v2026.8.19 route tests passed: short Luna xhigh priority, long Terra medium, and cross-provider rejection.
- Pre-deploy NUC usage baseline was read from `/var/lib/hermes-scintillate/.hermes/state.db`.
- `hey nuc-wt build` passed with `/nix/store/mfkmvwydapmqmwv60075n62a351f3n1l-nixos-system-nuc-26.11.20260714.18b9261`.
- `checks.x86_64-linux.nuc-buzz-hermes-community-runtime` and `checks.x86_64-linux.nuc-hermes-buzz-pilot` passed on the synced NUC worktree; the latter executed Hermes v0.20.5.
- A direct Darwin evaluation was not used as proof because it hit the repository's known cross-system overlay-function mismatch before the scoped attributes could evaluate.

## Reviews

- Cross-model plan review not run; `AGENT_WORKFLOW.md` makes it opt-in and the user did not request one.
- Landing gate pending.

## Feedback

- Direct unauthenticated `nix flake update` cannot refresh private `github:` inputs. Use the existing local `gh` credential on Darwin and `nix-private-github` on the NUC.

## Remaining work

- Land the dotfiles packaging changes.
- Deploy, restart, and verify the NUC generation.
- Prove live short/long route decisions, usage telemetry, and sibling isolation.

## Commits

Pending.
