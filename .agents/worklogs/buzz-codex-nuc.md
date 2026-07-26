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
- `hey nuc-wt build`, dry activation, and switch produced `/nix/store/vain38mnxjfp2hkfx4mjs84bf0b9nnsj-nixos-system-nuc-26.11.20260714.18b9261`. An initial empty-secret activation failed; replacing the corrected encrypted secret and switching again succeeded.
- A headless ACP prompt through the pinned `codex-acp` wrapper returned `CODEX_ACP_AUTH_OK` using `/home/emiller/.codex/auth.json`; no API key was added.
- Live NUC restart verification: service active as `emiller:users`, cwd `/home/emiller/mill-docs`, MainPID `255548`, `NRestarts=0`, secret mode `0400`. It reconnects outbound to the hosted relay and has no listener.
- Live positive allowlist test (2026-07-25T23:10Z): owner `fdb266…` mention `763081c7` → one worker reply `785272f8` with exact marker `OWNER_SINGLE_OK_20260725T2310Z`, correctly threaded.
- Live owner non-mention `OWNER_ROOT_NONMENTION_20260725T2312Z` received no response.
- Codex policy smoke test: write/read/delete in `~/mill-docs` and read `~/obsidian-vault/.git/HEAD` succeeded; a write in `/home/emiller` failed read-only; HTTPS access failed DNS resolution. Both probe paths were absent afterward.
- Local duplicate workers were stopped and receipts removed. The Mill Docs record has `start_on_app_launch: false` and no local `buzz-acp` process or receipt remains.
- Negative-path probes: outsider identity was rejected by relay admission (`403 relay_membership_required`) and self-mentions carry no `p` tag by design. Neither proves the author gate.
- The deployed build ran `cargo test --locked --package=buzz-acp author_gate_tests`; patched rejects for unlisted sibling and owner identities are covered in that module.
- A true member-but-not-allowlisted live mention remains blocked: Moni's relay pubkey/membership is unavailable and the available Fizz keychain item cannot be read from the terminal without a GUI authorization prompt. No credentials were printed or copied.

## Reviews

- Plan review: unavailable. Claude failed authentication, Gemini lacked ACP mode, and no Copilot adapter was installed; no heterogeneous reviewer could run.
- Landing review: pending final checks.
- `hey agent-finish` reached all substantive checks but its Nix-store closure resolves `jj` to the unrelated JSON editor, so the colocated-workspace test fails before task files; the current-source `python3 -m unittest tests/test_agent_quality.py` passed all 15 tests.

## Feedback

The NUC deployment guard correctly rejected dry activation after `origin/main` advanced past the worktree base. The first switch also exposed an empty encrypted-secret payload, which was corrected before the successful switch.

## Remaining work

- Obtain Moni's 64-character relay pubkey, admit her to the community, add her to `buzzMillDocsAllowedPubkeys`, deploy, and send her positive mention.
- Send one explicit `p`-tagged mention from a different admitted, nonallowlisted member and confirm no worker turn.

## Commits

- `97b4d71f8` `chore(packages): pin Codex ACP runtime`
- `a39a402cb` `test(buzz): cover exact respond-to allowlists`
- `9ef149ff9` `fix(buzz): enforce exact respond-to allowlists`
- `bcf8893d4` `feat(nuc): add owner-restricted Buzz Codex worker`
- `cd42fb45a` `fix(nuc): correct Buzz worker secret`
