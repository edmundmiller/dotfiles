# linear-agent-bridge

Openclaw gateway extension that receives Linear webhooks (@mentions, issue delegations) and dispatches autonomous agent runs.

**Upstream:** [edmundmiller/linear-agent-bridge](https://github.com/edmundmiller/linear-agent-bridge)

## How It Works

```
Linear @mention → webhook → openclaw gateway → linear-agent-bridge → agent run
                                  ↑
                          LINEAR_API_KEY (OAuth app-user token, actor=app)
```

The bridge authenticates as **Norbot** (Linear OAuth app-user). Tokens auto-rotate via `linear-token-refresh.timer` on the NUC every 12h.

## Updating

1. Push changes to `edmundmiller/linear-agent-bridge`
2. Update `rev` and `hash` in `default.nix`:
   ```bash
   # Get new rev
   git -C /path/to/linear-agent-bridge rev-parse HEAD
   # Prefetch new hash
   nix-prefetch-fetchFromGitHub --owner edmundmiller --repo linear-agent-bridge --rev <new-rev>
   # Or just set hash to empty string, build, and copy the correct hash from the error
   ```
3. If deps changed, update `npmDepsHash` (same empty-string trick works)
4. Deploy: `hey nuc`

## OAuth Token Lifecycle

Linear OAuth tokens expire every 24h. The NUC auto-rotates them:

- **`linear-token-init.service`** — oneshot before gateway, refreshes token on boot
- **`linear-token-refresh.timer`** — every 12h, refreshes + restarts gateway
- **Persisted state** — `~/.local/state/openclaw-linear/{token,refresh-token}`

Linear rotates refresh tokens on each use. The refresh script persists the new one. If the chain breaks: `linear-oauth-refresh` from Mac re-bootstraps.

## Key Files

| File                                       | Purpose                        |
| ------------------------------------------ | ------------------------------ |
| `packages/linear-agent-bridge/default.nix` | Nix package (buildNpmPackage)  |
| `hosts/nuc/default.nix`                    | Token services, gateway config |
| `hosts/nuc/secrets/linear-*.age`           | Agenix-encrypted token seeds   |
| `bin/linear-oauth-refresh`                 | Manual token re-bootstrap      |
| `bin/test-linear-agent`                    | Smoke test (fake webhook)      |

## Gotchas

- **Must use `actor=app`** in OAuth URL — personal user tokens can't call `agentActivityCreate`
- **Label truncation** — Linear enforces 64-char limit on labels; fixed in commit `cb09637`
- **Refresh token rotation** — Each refresh invalidates the old refresh token. If the script doesn't persist the new one, the chain dies. This was the root cause of the Feb 2026 outage.
