# Worklog: buzz-codex-nuc

Status: active

## Objective

Run a persistent, restartable `buzz-acp` system service on the NUC as `emiller`. It must connect outbound to `wss://millers.communities.buzz.xyz`, invoke Codex through a pinned `codex-acp` adapter from `/home/emiller/mill-docs`, respond only to explicit mentions from the allowlisted owner and Moni identities, reuse the existing ChatGPT Codex login, and expose no inbound port.

Stopping condition: packages build on Linux, secrets and hosted-relay credentials materialize without disclosure, NUC dry activation and switch succeed, the service is active after restart, an allowlisted Buzz mention receives a Codex response, a non-mention and non-allowlisted message receive no response, and Codex filesystem probes preserve the existing `mill-docs`/`obsidian-vault` boundary.

## Decisions

- Use a NixOS system service under the existing `emiller` account so the service reuses `/home/emiller/.codex` authentication and project policy.
- Treat Buzz identity/channel access and Codex/OS filesystem policy as separate boundaries.
- Keep the worker mention-only with one Codex subprocess and an explicit author allowlist.
- Pin all three runtime components; do not use `npx -y` at service startup.

- Carry a focused Buzz patch because upstream `allowlist` also admits same-owner sibling agents and ignores the explicit list in DMs.
- Invoke `codex-acp` through a differently named wrapper so Buzz does not override the existing Codex project network policy.

## Evidence

- Execution host: `MacTraitor-Pro.local`, Darwin arm64.
- Task branch rebased onto current `origin/main`; unrelated changes remain in the original worktree.
- Buzz v0.4.26 and codex-acp v1.1.7 are source-pinned; both Nix packages build on Darwin and in the NUC system closure.
- The exact-allowlist regression failed in the three expected cases before the Buzz fix, then all 16 focused author-gate tests passed.
- The encrypted `buzz-mill-docs-agent-env.age` contains the dedicated identity key and validated NIP-OA owner attestation. Relay profile `6149257abdc1b4a9da4b23fdf11fd2e3b06ecbca050491a06585342c5484caee` now identifies as `Mill Docs`.
- `hey nuc-wt build` produced `/nix/store/w27wpxzqg386mdz8qf8agxjli6b40dha-nixos-system-nuc-26.11.20260714.18b9261`; `hey nuc-wt dry-activate` completed without activation errors.
- A headless ACP prompt through the pinned `codex-acp` wrapper returned `CODEX_ACP_AUTH_OK` using `/home/emiller/.codex/auth.json`; no API key was added.
- Live NUC: `buzz-mill-docs-codex.service` active (MainPID 3794325, NRestarts=0), running `/nix/store/7r110xrm5my4qj1i1s82sb2lks78wfva-buzz-0.4.26` (patched build).
- Live positive allowlist test (2026-07-25T23:10Z): owner `fdb266…` mention `763081c7` → worker reply `785272f8` with exact marker `OWNER_SINGLE_OK_20260725T2310Z` 14s later, correctly threaded.
- Negative-path probes: ephemeral outsider key was rejected at relay admission (`403 relay_membership_required`) — wrong layer, not gate evidence. Self-mention probes (`614925…` mentioning itself) carried no `p` tag by design (sender-side self-mention normalization in `buzz-sdk::mentions::normalize_mention_pubkeys`) — invalid as mention tests. The Mac `npub` encoder was validated against both `mentions.rs` test vectors.
- The deployed Nix build ran `cargo test --locked --package=buzz-acp author_gate_tests`; the patched reject assertions (`test_allowlist_rejects_sibling_not_in_allowlist`, `test_allowlist_rejects_unlisted_owner`, DM variants) live in that module, so the exact-allowlist gate is build-verified on the deployed binary.
- Local duplicate `Fizz` worker (pid 1766, pubkey `7782750b…`) stopped via verified TERM; its runtime receipt removed. Buzz v0.4.26 `restore_managed_agents_on_launch` only respawns records with `start_on_app_launch = true` (`is_active` is not a restore predicate), so it stays stopped across app restarts.
- Live negative (member-but-not-allowlisted `Fizz` `78f3f153…` → mention must be dropped) is blocked reading the sender key: `security find-generic-password -s buzz-desktop -a secrets -w` timed out twice (30s, 300s) with no observed dialog or approval. Likely a GUI authorization prompt from an unsigned terminal, but that is unconfirmed.

## Reviews

- Plan review: unavailable. Claude failed authentication, Gemini lacked ACP mode, and no Copilot adapter was installed; no heterogeneous reviewer could run.
- Landing review: pending.

## Feedback

The NUC deployment guard correctly rejected dry activation after `origin/main` advanced past the worktree base.

## Remaining work

- Run the live negative: send, as channel member `78f3f1537adb3c6b968ebcd2c5835532c30a2ab8edba8f521a02eb8ea4cb6a9c` (Fizz, same-owner sibling, not allowlisted), a message to channel `ebe6fa65-e776-46e6-9c79-7dae679ad1de` containing `nostr:npub1v9yj274acx62nkjty07lz87juwcxaj72q5zfrgr9s56zc4yyethq3f5j67 NONALLOWLISTED_SIBLING_<ts>` with `BUZZ_PRIVATE_KEY` from the keychain blob entry `agent:78f3f153…` and `BUZZ_AUTH_TAG` from its `managed-agents.json` record. Confirm the accepted event carries a `p` tag for `614925…` and `journalctl -u buzz-mill-docs-codex.service` shows no turn. If the keychain read still hangs, approve the macOS dialog once ("Allow", not "Always Allow") or run the send from a signed context.
- Add Moni's relay identity to the exact allowlist after she joins the community or provides her 64-character pubkey.
- Exercise filesystem boundary probes after Moni joins and is allowlisted.

## Commits

- `b7e510e07` `chore(packages): pin Codex ACP runtime`
- `4b50ec455` `test(buzz): cover exact respond-to allowlists`
- `8a7b64491` `fix(buzz): enforce exact respond-to allowlists`
