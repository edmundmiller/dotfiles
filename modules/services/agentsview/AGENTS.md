# AgentsView

NUC runs `agentsview pg serve` on `127.0.0.1:8087` as `agentsview`, with local
PostgreSQL database `agentsview`. `agentsview-pg.service` serves a read-only
shared dashboard; `agentsview-tailscale-serve.service` exposes
`https://agentsview.cinnamon-rooster.ts.net` through `svc:agentsview`.

Sync is one-way: each workstation pushes its local SQLite/session data to PG.
Keep PostgreSQL private; remote pushes use an SSH Unix-socket tunnel, e.g.
`ssh -N -L 15432:/run/postgresql/.s.PGSQL.5432 nuc`, then a configured
`agentsview pg push --full --all-projects` when sharing is authorized.

App bearer auth is separate from Tailscale. The service generates and preserves
the token in `/var/lib/agentsview/.agentsview/config.toml`; its 1Password
reference is `op://Agents/AgentsView/password`. Do not print it in diagnostics.

Inspect the two units/journals and `tailscale serve status --json` for
`svc:agentsview`. Approval/ACL recovery belongs in the tailnet repo as described
in the parent service guide.
