# ADR 0007: Scintillate Hermes auth state and model smoke monitoring on the NUC

## Status

Accepted

## Context

Scintillate is deployed on the NUC as a Hermes profile. It should primarily use the user's Codex subscription through Hermes' `openai-codex` provider because that subscription is dramatically more economical for normal Scintillate usage than raw API or OpenRouter spend.

The live deployment previously attempted to make Scintillate use the user's Codex CLI login by importing or pointing at `/home/emiller/.codex/auth.json`. That failed because Codex OAuth refresh tokens rotate and are effectively single-owner. Sharing the CLI token with Hermes caused errors including:

- `refresh_token_reused`
- `token_expired`
- `Codex auth is missing access_token. Run hermes auth to re-authenticate.`

During the incident, OpenRouter restored service but became an expensive default. The canonical agent config now keeps Codex primary, routes agentic fallback through Nous Portal, and uses OpenRouter auto only for simple/cheap routing. Dotfiles owns the NUC-specific runtime/auth operations around that canonical config.

## Decision

On the NUC, Scintillate's Hermes profile has its own provider auth state and operational checks.

- Do not import, copy, seed, or periodically sync `/home/emiller/.codex/auth.json` into Scintillate.
- Do not set Scintillate `authFile` to the user's Codex CLI auth file.
- Treat `/var/lib/hermes-scintillate/.hermes/auth.json` as Scintillate's Hermes-owned runtime auth store.
- Re-authenticate Scintillate through Hermes itself when Codex auth expires or is invalidated.
- Monitor the actual Codex model path with a systemd smoke service rather than relying only on process liveness.

Current host-owned operational pieces:

- `hermes-scintillate-codex-smoke.service` directly invokes `openai-codex / gpt-5.5` and alerts on failure.
- `hermes-scintillate-codex-smoke.timer` runs that check periodically.
- `hey login-scintillate` is the supported re-auth helper for Scintillate Codex login.
- The NUC eval test asserts that the old Codex auth import service is absent and Scintillate `authFile` remains unset.

## Ownership boundary

`agents-workspace` owns canonical Scintillate routing:

- primary model/provider;
- fallback model/provider;
- smart/simple routing defaults;
- reusable comments and agent-level intent.

Dotfiles owns concrete NUC deployment choices:

- secret references and token file paths;
- systemd services/timers and alerting;
- Telegram bot token wiring;
- login helper commands;
- NUC-specific eval assertions;
- rebuild/deploy mechanics.

## Runtime auth stores

Scintillate has separate auth surfaces:

- User Codex CLI auth: `/home/emiller/.codex/auth.json`
- Scintillate Hermes auth: `/var/lib/hermes-scintillate/.hermes/auth.json`

These files must not be treated as interchangeable. The Codex CLI file is owned by the user's CLI session. The Hermes file is owned by Scintillate's service runtime.

Do not print token values while debugging. It is acceptable to inspect auth shape, provider names, credential labels, and expiry metadata if needed, but not access tokens or refresh tokens.

## Model routing implications

The expected rendered Scintillate config on the NUC is:

```yaml
model:
  provider: openai-codex
  default: gpt-5.5
  thinking: low

fallback_model:
  provider: nous
  model: anthropic/claude-sonnet-4.6

smart_model_routing:
  cheap_model:
    provider: openrouter
    model: openrouter/auto
```

If Codex fails, Hermes may need to use the Nous fallback. That fallback requires a valid Nous Portal login in Scintillate's Hermes auth store. OpenRouter remains available for simple/cheap routing, but should not become the normal full-agent fallback unless explicitly revisited.

## Operational procedures

For Codex re-login, use:

```bash
hey login-scintillate
```

That helper runs the device login flow for Scintillate, verifies a direct Codex invocation, and runs the smoke service.

For manual verification on the NUC:

```bash
systemctl status hermes-scintillate-codex-smoke.service --no-pager -l
systemctl list-timers hermes-scintillate-codex-smoke.timer --no-pager
docker exec hermes-agent-scintillate bash -lc \
  'timeout 180 hermes --provider openai-codex -m gpt-5.5 -z "Reply with exactly: OK"'
```

For Nous fallback verification, first log Scintillate into Nous Portal through Hermes, then run a direct `--provider nous` smoke invocation. Do not route Nous through OpenRouter when testing this fallback.

## Consequences

Positive:

- Codex subscription economics are preserved for normal Scintillate use.
- Auth ownership is explicit and avoids rotating refresh-token reuse bugs.
- A real model invocation catches auth failures that liveness checks miss.
- Re-login has a single documented helper.
- The host test prevents reintroducing the broken auth import pattern.

Tradeoffs:

- Scintillate runtime auth is mutable state and must be handled like service state, not pure declarative config.
- Operators need separate login procedures for Codex primary and Nous fallback.
- Smoke checks exercise paid/subscription model paths, so their cadence should stay modest.

## Security notes

An early smoke-test implementation briefly exposed the Scintillate Telegram bot token in process arguments. Rotate `telegram-bot-token-scintillate` and keep alerting scripts structured so secrets are passed by file/environment reference, never as command-line arguments or log text.

## Verification

The current NUC deployment should pass:

- `nix build .#checks.x86_64-linux.nuc-scintillate-runtime-access --show-trace`
- `nixos-rebuild switch --flake .#nuc --show-trace`
- `systemctl is-active hermes-gateway-scintillate.service`
- `systemctl start hermes-scintillate-codex-smoke.service`

Expected smoke result: service exits successfully after the direct Codex invocation returns `OK`.

## Follow-up

- Rotate the Scintillate Telegram bot token.
- Add a Nous Portal login helper and smoke check once the fallback is logged in.
- Keep OpenRouter emergency/full-agent fallback out of the default path unless Codex and Nous economics or reliability change.
