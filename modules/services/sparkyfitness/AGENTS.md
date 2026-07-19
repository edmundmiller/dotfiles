---
purpose: Operate and recover the NUC SparkyFitness deployment.
applies_to: Changes under modules/services/sparkyfitness or its NUC state and secrets.
entrypoint: Edit default.nix, then validate with hey nuc-wt build.
verification: Check the Compose unit, private HTTPS endpoint, backup, and Gatus status.
update_when: Images, ports, mounts, secrets, ingress, or recovery steps change.
---

# SparkyFitness operations

The module runs the pinned upstream frontend, backend, and PostgreSQL images as one Docker Compose stack. Only `127.0.0.1:3004` is published. Tailscale Serve exposes `svc:sparkyfitness`; no firewall port or Funnel is used.

State lives under `/var/lib/sparkyfitness`. Restic stops `sparkyfitness.service`, snapshots that directory, then restarts the stack.

## Secret recovery

`hosts/nuc/secrets/sparkyfitness-env.age` is the source of deployment credentials. Recreate the seven required environment values, encrypt the file to both the operator and NUC recipients declared in `hosts/nuc/secrets/secrets.nix`, rebuild, and restart `sparkyfitness.service`.

Keep the API encryption key and Better Auth secret stable. Rotating the encryption key invalidates encrypted integrations. Rotating the Better Auth secret invalidates sessions and two-factor state.

Never print or commit plaintext secret values.
