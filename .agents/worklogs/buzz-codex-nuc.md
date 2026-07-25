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

## Reviews

- Plan review: unavailable. Claude failed authentication, Gemini lacked ACP mode, and no Copilot adapter was installed; no heterogeneous reviewer could run.
- Landing review: pending.

## Feedback

The NUC deployment guard correctly rejected dry activation after `origin/main` advanced past the worktree base.

## Remaining work

- Add Moni's relay identity to the exact allowlist after she joins the community or provides her 64-character pubkey.
- Switch and exercise positive/negative Buzz mentions plus filesystem boundaries after Moni joins and is allowlisted.

## Commits

- `b7e510e07` `chore(packages): pin Codex ACP runtime`
- `4b50ec455` `test(buzz): cover exact respond-to allowlists`
- `8a7b64491` `fix(buzz): enforce exact respond-to allowlists`
