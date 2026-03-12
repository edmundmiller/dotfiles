<!-- NUC finances Dagster deployment: where config lives and how to operate it. -->

# Finances Dagster on NUC (systemd)

This repo deploys finances Dagster on NUC as a **Dagster code location** under the shared Dagster stack.

## Where it is configured

- Service module:
  - `modules/services/finances-dagster/default.nix`
- NUC host enablement + healthcheck URL:
  - `hosts/nuc/default.nix` under `modules.services.finances-dagster`
- Shared Dagster base services (webserver/daemon/workspace wiring):
  - `modules/services/dagster/default.nix`

## Runtime wiring

`modules/services.finances-dagster` configures:

- Dagster gRPC code location name: `finances`
- `BEANCOUNT_DAILY_HEALTHCHECK_URL` (daily schedule run-status sensor pings)
- `DAGSTER_HOME` (inherited from shared Dagster module)
- `UV_CACHE_DIR`, `UV_PYTHON_PREFERENCE`, `SSL_CERT_FILE`
- PATH entries for `just`, `op`, `uv`, etc.
- Optional 1Password service account token injection from `/etc/opnix-token`

No systemd timer is needed for daily sync itself — `daily_beancount_sync_schedule` runs via `dagster-daemon`.

## Deploy

```bash
cd ~/.config/dotfiles
hey nuc
```

## Check status on NUC

```bash
# Shared Dagster services
systemctl status dagster-webserver.service dagster-daemon.service

# Finances code location service
systemctl status dagster-code-finances.service

# Optional setup/token helper units
systemctl status finances-dagster-setup.service finances-dagster-op-env.service

# Logs
journalctl -u dagster-code-finances.service -n 200 --no-pager
journalctl -u dagster-daemon.service -n 200 --no-pager
```

Dagster UI remains on NUC Dagster webserver port (currently `3001` in host config).

Local `launchd` setup in `~/src/personal/finances` should remain as dev/fallback only.
