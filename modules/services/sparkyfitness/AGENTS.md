# SparkyFitness

Pinned frontend/backend/PostgreSQL images run as a Compose stack through NUC's
Podman Docker-compatible API. Only `127.0.0.1:3004` is published; Tailscale Serve
exposes `svc:sparkyfitness`, without firewall openings or Funnel.

State is `/var/lib/sparkyfitness`. Restic stops `sparkyfitness.service`, snapshots
the directory, then restarts it. Deployment verification includes the unit,
private HTTPS endpoint, backup, and Gatus status.

`hosts/nuc/secrets/sparkyfitness-env.age` owns seven environment values, encrypted
to operator and NUC recipients. Keep the API encryption key and Better Auth
secret stable: rotation invalidates integrations or sessions/two-factor state.
Recovery requires authorized re-encryption, rebuild, and service restart.
