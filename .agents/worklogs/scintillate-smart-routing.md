# Worklog: scintillate-smart-routing

Status: complete

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
- The NUC switched to `/nix/store/xiixskz555h8s8nyp5qrxxf8mza4i3kv-nixos-system-nuc-26.11.20260714.18b9261` from authoritative dotfiles `main` at `b9165cbb638d204f4983e31c988521fc5fa3f1e0`.
- After a no-active-turn check, only `hermes-gateway-scintillate.service` was restarted. It adopted `/nix/store/z0s8zab0wxn3ckwm2i3bmkssgqhbls0s-hermes-agent-buzz-pilot-2026.8.19-runtime`, remained active with `NRestarts=0`, and reconnected Buzz, email, Home Assistant, and API server.
- Live rendered config readback: Terra/openai-codex with medium reasoning; enabled short route at 100 characters and 8 words to Luna/openai-codex with xhigh reasoning and fast service tier.
- The installed gateway source passed the three route seam checks: bounded short Luna priority, long Terra, and cross-provider rejection.
- All Buzz sibling services and Orchestrator remained active with `NRestarts=0`; only Scintillate runs the v0.20.5 pilot package.
- Seven-day `session_model_usage` readback: Luna 105 calls and Terra 106 calls; subscription-included rows report `$0.00` estimated and actual incremental cost.
- `hey agent-audit-tests` and `hey agent-finish` passed; repo quality, 56 agent-quality tests, rules, skills, inventory, and changed test confidence were green.

## Reviews

- Cross-model plan review not run; `AGENT_WORKFLOW.md` makes it opt-in and the user did not request one.
- Landing gate passed.

## Feedback

- Direct unauthenticated `nix flake update` cannot refresh private `github:` inputs. Use the existing local `gh` credential on Darwin and `nix-private-github` on the NUC.

## Remaining work

None.

## Commits

- `f8ebd6046fb04d60427b2335ce6d921122ccc532` (`agents-workspace/main`): bounded routing contract, patch, config, and docs.
- `b9165cbb638d204f4983e31c988521fc5fa3f1e0` (`dotfiles/main`): package the patch, pin the source, and assert Scintillate-only isolation.
