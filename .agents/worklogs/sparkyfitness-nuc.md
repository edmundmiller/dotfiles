# Worklog: sparkyfitness-nuc

Status: complete

## Objective

Deploy a pinned, x86_64-linux-compatible SparkyFitness stack on the NUC with tailnet-only ingress, durable state, secret-backed credentials, backup coverage, Gatus monitoring, and verified rollback. Stop only after repository checks, NUC build/dry-activation/deployment, runtime and persistence checks, landing reviews, commit, rebase, push, and upstream-current verification succeed.

## Decisions

- Reuse the repository's existing container, ingress, persistence, secret, backup, and monitoring conventions after verifying them.
- Never expose SparkyFitness publicly or deploy an unpinned `latest` image.
- Use the repository's established Docker Compose seam for multi-container stacks and its Tailscale Services ingress; do not manually recreate Compose networking in OCI-container units or add a second proxy.
- Deploy SparkyFitness v0.17.3 with the published multi-architecture image-index digests and PostgreSQL 18.3 Alpine.
- Use a dedicated PostgreSQL container on the Compose network to isolate credentials and migrations from the NUC's shared PostgreSQL service.
- Bind only the frontend to `127.0.0.1:3004`; keep backend port 3010 and PostgreSQL 5432 on the private container network.
- Publish through `svc:sparkyfitness` at `https://sparkyfitness.cinnamon-rooster.ts.net`; Gatus checks that user-facing private URL.
- Implement a dedicated `modules/services/sparkyfitness/` module with an evaluation test covering private binding, secrets, supervision, ingress, and backup wiring.
- Let Compose create the private bridge and service DNS. Add PostgreSQL and backend health checks, gate backend on a healthy database and frontend on a healthy backend, and start the systemd unit with `docker compose up -d --wait`.
- Store all required values in `hosts/nuc/secrets/sparkyfitness-env.age`, owned by root and loaded by the database and backend containers. Agenix is sufficient because these are stable deployment secrets, not externally rotated credentials.
- Back up `/var/lib/sparkyfitness` only while the Compose stack is down; restart both the stack and its dependent Tailscale Serve unit after Restic completes. This yields a consistent PostgreSQL data directory plus uploads and application backups without handling plaintext credentials.
- The eval test asserts the exact pinned images, loopback binding, durable mounts, private service DNS, health dependencies, environment-file path, clean shutdown, no firewall opening, Tailscale Serve target/service, and Restic stop-start hooks. Remote build and runtime checks cover the generated Compose, all health checks, ingress, and backup recovery.
- Provision `svc:sparkyfitness` and its explicit ACL grant in the authoritative `~/src/personal/tailnet` repository before deployment; verify the service reports `approved:auto` and `configured:ready`.
- Runtime verification will exercise Compose health, frontend HTTP, backend `/api/health`, private Tailscale HTTPS, public-interface refusal, service restart persistence, Restic path coverage, and Gatus health.
- Document secret recovery in the module guide: re-encrypt `sparkyfitness-env.age`, rebuild, and restart the stack; rotating the API encryption key invalidates encrypted integrations and rotating Better Auth invalidates sessions/2FA.

## Evidence

- Host preflight: `hostname` returned `MacTraitor-Pro.local`; `uname -a` confirmed Darwin arm64.
- Workspace preflight: clean Git worktree on `worktree/quiet-field-7ed5`.
- Target architecture: the NUC is `x86_64-linux`; live units confirm Docker and Podman are installed, while existing multi-container services use Docker Compose.
- Upstream v0.17.3 requires PostgreSQL, backend, and frontend services; required secrets are database owner/app passwords, a 64-character API encryption key, and a persistent Better Auth secret.
- Published image indexes include `linux/amd64`: frontend `sha256:46d90e46bd87312fcbbbb05036d99e4cb1c821e928b0516ee727de4c3c90752b`, backend `sha256:6aa7d9832324ea403be144a26398a82afbf04abbb4da89f9d04ba61838516b3f`, PostgreSQL `sha256:54451ecb8ab38c24c3ec123f2fd501303a3a1856a5c66e98cecf2460d5e1e9d7`.
- Registry verification used `docker manifest inspect` and `docker buildx imagetools inspect`; each recorded image-index digest was observed directly and each index includes `linux/amd64`.
- PostgreSQL 18.3 is current in July 2026: upstream SparkyFitness's published Compose file specifies `postgres:18.3-alpine`, and Docker Hub returned the official multi-platform image index and digest recorded above.
- Upstream health checks use frontend `/` and backend `/api/health`; durable mounts are PostgreSQL state, server uploads, and server backups.
- Live NUC Docker Compose is 5.3.1 and `docker compose up --help` confirms `--wait` and `--wait-timeout`.
- Tailnet provisioning created `svc:sparkyfitness` with addresses `100.110.97.40` and `fd7a:115c:a1e0::6f3a:612c`; the authoritative ACL applied successfully. No device is configured before NUC deployment, as expected.
- `hey nuc-wt build` built the NUC generation successfully, including the Compose file, Gatus config, Tailscale Serve unit, agenix secret, and Restic unit.
- The Linux-only `sparkyfitness-assertions` check passed all 16 assertions on the NUC.
- Initial `hey nuc dry-activate` correctly refused a stale source base: local HEAD `05eca37b` trails `origin/main` `eb72109b`. Land the implementation commit, rebase, then repeat dry activation.
- First activation reproduced a deterministic PostgreSQL startup failure: the Alpine image runs PostgreSQL as UID/GID 70, while tmpfiles created its bind mount as root-only. The module now assigns `/var/lib/sparkyfitness/postgresql` to `70:70`, and the eval check locks that runtime requirement.
- The deployment succeeded after the ownership correction. The PostgreSQL, backend, and frontend containers all report `healthy`; loopback frontend HTTP and backend `/api/health` return successfully; private Tailscale HTTPS returns the frontend; and `192.168.1.222:3004` refuses connections.
- Persistence was verified with a temporary account and a 123.5 check-in across a stack restart, then the temporary account was deleted from both application and authentication tables. A subsequent login attempt returned `Invalid credentials.`
- Restic snapshot `4feb549e` completed successfully. It exposed a dependent-unit regression: stopping `sparkyfitness.service` also stopped its `Requires=` Tailscale Serve unit, while cleanup restarted only the stack. A strict expected-failure assertion captured this; cleanup now starts both units, and the passing evaluation check covers it.
- A fresh remote `restic-backups-sparkyfitness-state.service` run completed with `Result=success` and `ExecMainStatus=0`; both `sparkyfitness.service` and `sparkyfitness-tailscale-serve.service` were active afterward. `tailscale serve status --json` confirms `svc:sparkyfitness` proxies `sparkyfitness.cinnamon-rooster.ts.net:443` to `127.0.0.1:3004`.
- Final remote `hey nuc-wt build` succeeded. The NUC-built `.#checks.x86_64-linux.sparkyfitness-assertions` derivation succeeded; attempting that Linux-only check locally correctly failed with platform mismatch, so it is validated only on the NUC.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` succeeded. `hey check` reaches the Darwin evaluation successfully, then its treefmt and pre-commit phases fail before checking files because `bin/hey.d/flake.nu` invokes `prek run` but this worktree has neither `prek.toml` nor `.pre-commit-config.yaml`; this is an existing harness configuration gap, not a SparkyFitness failure.

## Reviews

- Approved user plan: `local://sparkyfitness-nuc-deployment-plan.md`.
- Plan gate attempt with Claude failed before review because ACP authentication was unavailable.
- Plan gate with OpenCode returned NOT PASS. Resolved its architectural findings by choosing a dedicated module, dedicated PostgreSQL container, private Podman bridge, loopback port 3004, `svc:sparkyfitness`, and a focused Nix evaluation test. The approved plan is a harness-local artifact, so its absence from the Git worktree is expected; the executing agent read and recorded it before implementation.
- Second OpenCode plan gate returned NOT PASS. Resolved its blockers by recording independent digest evidence, exact shared-network aliases and dependency chain, the `sparkyfitness-env.age` contract, full eval assertions, and a stopped-stack Restic strategy for consistent PostgreSQL files.
- Third OpenCode plan gate returned NOT PASS because manual OCI ordering does not wait for readiness and duplicated the established Compose stack pattern. Resolved by switching to Compose with health-gated dependencies and `up -d --wait`; the stopped-stack backup now manages one systemd unit.
- Fourth OpenCode plan gate returned CONDITIONAL PASS. Rejected its claim that PostgreSQL 18.3 does not exist using the observed upstream Compose file and Docker official registry manifest. Resolved its remaining concerns by adding the external tailnet provisioning/verification, runtime smoke matrix, backup downtime rationale, and secret recovery contract.
- Fifth OpenCode plan gate found no architectural rejection. Resolved its operational blockers by requiring a oneshot/RemainAfterExit unit with `ExecStop = docker compose down --timeout 60`, so systemd waits for PostgreSQL's clean SIGTERM shutdown before Restic reads state. Kept the approved user-facing Tailscale Gatus check; it intentionally covers ingress plus application availability. Homepage integration is outside the approved scope.
- Landing gate with the explicit OpenCode reviewer returned PASS. Its only blocking worklog finding (duplicate Feedback headings) is resolved below; its Gatus status-condition and style-commit notes are non-blocking and require no change because the frontend returns 200 and the Gatus guide is part of the documented endpoint change.

## Feedback

- `hey check` is not self-contained in this worktree: its formatting and pre-commit commands require an undiscoverable Prek manifest. The resulting `repo-quality` failure is unrelated to this deployment and must be repaired in the check harness separately.

## Remaining work

- None.

## Commits

- `b20cbbfe feat(nuc): deploy SparkyFitness`
- `b92bcf58 test(nuc): capture SparkyFitness state ownership bug`
- `bfa2847d fix(nuc): make SparkyFitness database state writable`
- `27edf58b test(nuc): capture SparkyFitness backup ingress regression`
- `e29d165f fix(nuc): restore SparkyFitness ingress after backup`
- `fdba0205 style(nuc): format SparkyFitness service docs`
- `81ab24c0 docs(worklog): record SparkyFitness deployment`
