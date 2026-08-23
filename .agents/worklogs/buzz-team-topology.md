# Worklog: buzz-team-topology

Status: active

## Objective

Deploy the approved first Buzz topology layers from a clean dotfiles worktree: stop public Orchestrator intake, keep Amos on report delivery only, preserve Scintillate as the mention-gated native owner, and later bind Betty to the private household surface. Stop if the owner-authenticated Buzz mutation cannot be verified, a required secret is missing, or switching would interrupt an active Scintillate turn.

## Decisions

- Keep Orchestrator's native Hermes gateway for internal Kanban and remove only its `buzz-hermes-orchestrator` public listener.
- Keep Amos's Buzz identity and report delivery while removing `general` intake.
- Preserve Scintillate's native gateway, guarded restart policy, author allowlist, mention requirement, and presence companion.
- Consume channel and profile intent from the pinned `agents-workspace` input; do not duplicate channel IDs in host code.

## Evidence

- Pre-change NUC services: all five `buzz-hermes-*` listeners active with `NRestarts=0`; Scintillate gateway and presence active.
- Live `general` membership: Edmund, Moni, Orchestrator, Scintillate, Amos Burton, Radar, and Claude.
- Agents source commit `a7323a7` makes `general` human-first and removes the public Orchestrator profile; focused Nix binding and delivery checks passed.
- Full NUC evaluation failed red at `buzzBindings.profiles.orchestrator`, proving the stale public service still depended on the retired binding.
- The first switch activated the target system and preserved Scintillate's PID, but `opnix-secrets.service` hit a 1Password rate limit and made `nixos-rebuild` return 4. Existing declared values were preserved; authoritative service readback is required before retrying once.
- The focused Linux check `nuc-buzz-hermes-community-runtime` passed on the NUC after removing the listener and host secret registry entry.
- Live system `/nix/store/v3vjaayrayfbfnq0cy1bw0fp54lzz92h-nixos-system-nuc-26.11.20260714.18b9261` has no `buzz-hermes-orchestrator` unit or decrypted Orchestrator Buzz identity. The internal Orchestrator gateway, four sibling listeners, Scintillate gateway, and Scintillate presence are active with zero restarts.
- Amos now has only the `agent-reports` channel in its generated config and remains mention-gated.
- Scintillate retained PID `2965288` and start time `2026-08-22 21:54:54 CDT` through both switches.

## Reviews

- Automated heterogeneous plan gate attempted with `hey agent-review plan --active-model-family openai`; ACP session creation returned `RUNTIME: Authentication required`. The user explicitly approved the topology implementation, so work proceeds with the exact unavailable-reviewer blocker recorded.

## Feedback

- Live Buzz membership can drift from executable bindings; deployment verification must compare both.
- Parked: `opnix-secrets.service` remains rate-limited after the single allowed retry, and the unrelated `mill-docs-git-pull.service` found pre-existing unmerged files. Neither task-owned service depends on those refreshes, and existing Hermes values were preserved.

## Remaining work

- Complete owner-authenticated Buzz membership changes and re-read the channel.

## Commits

- Agents source: `a7323a7 feat(buzz): make general human-first`
- Dotfiles: `feat(buzz): internalize orchestrator intake`.
