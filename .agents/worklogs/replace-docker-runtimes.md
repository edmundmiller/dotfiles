# Worklog: replace-docker-runtimes

Status: blocked only on macOS admin cleanup; source and NUC deployment landed

## Objective

Remove Docker Engine/Desktop runtime declarations from the dotfiles-managed
profiles, use OrbStack for Docker-compatible macOS consumers, use Podman on
Linux, and preserve portable Compose/Dockerfile/OCI contracts. Stop with
authoritative source and live runtime evidence; do not cut over active NUC
workloads without a workload-by-workload Podman readback.

## Decisions

- Replaced the Docker service module with `modules.services.containers`.
- Darwin selects OrbStack and pins `DOCKER_CONTEXT=orbstack`; Apple Container
  remains enabled on MacTraitor-Pro for its existing native pilot.
- Linux selects Podman with `dockerCompat` and `dockerSocket.enable` only as
  compatibility shims for Compose and Docker-API consumers.
- Kept Docker Compose commands and Docker/OCI asset paths where they are
  portable or required external contracts; removed Docker Machine shell and
  prompt hooks.
- Authorized the live interruption after an exact preflight. Preserved all
  workload bind data and configuration; no Docker images, volumes, contexts,
  credentials, or `/var/lib/docker` data were deleted.

## Evidence

- `nix build .#checks.aarch64-darwin.apple-container-pilot-assertions --no-link`
  passes.
- `hey check --worktree` passes all Darwin-compatible, formatting, hook, tmux,
  package, policy, and ast-grep checks.
- `hey agent-audit-tests` passes test-confidence for the focused runtime tests;
  `hey agent-finish --dry-run` validates the worklog and landing manifest.
- `nix eval` confirms Meshify, Unas, and NUC select Podman and evaluate
  `virtualisation.docker.enable = false`.
- `hey nuc-wt build` succeeds on the NUC and builds Podman compatibility plus
  affected Compose/systemd units.
- `hey nuc-wt dry-activate` plans to stop Docker units and start the Podman-
  backed Latitude, Open Wearables, and SparkyFitness units.
- Live NUC `sudo podman run --rm alpine echo podman-runtime-ok` passes;
  Podman Docker API shim returns server `5.8.4` and lists rootful Podman
  services.
- Live MacTraitor-Pro has OrbStack active with context `orbstack`, but Docker
  Desktop had restarted; a targeted quit followed by SIGTERM of only its main
  process stopped it. The exact `/Applications/Docker.app` bundle and its
  Homebrew caskroom receipt were moved to `~/.Trash` (recoverable). Docker
  Desktop data under `~/Library/Containers/com.docker.docker` and `~/.docker`
  remain untouched. Root-owned Docker helper cleanup still awaits macOS admin
  authorization; OrbStack remains healthy.
- Fresh NUC preflight identified host `nuc`, account `emiller`, Docker Engine
  29.6.1, and active Hermes/Latitude/SparkyFitness/Open Wearables units with
  durable bind mounts. The first reversible test activation exposed that
  systemd Compose units did not inherit the shell `DOCKER_HOST`; it failed
  before replacement containers started.
- Added explicit `DOCKER_HOST=unix:///run/podman/podman.sock` to all three
  systemd Compose units. After removing only the stale Docker socket and
  restarting `podman.socket`, the second test activation started every
  affected unit and recreated the stacks in Podman. Podman rootful API
  compatibility returned server `5.8.4`; Compose returned `5.3.1`.
- Live post-cutover readback: Docker Engine and socket inactive (`docker.service`
  not-found), `/var/run/docker.sock` points to Podman, all affected units are
  active, healthchecks are green where defined, and HTTP checks returned
  Latitude web 200, SparkyFitness 200, and Open Wearables `/docs` 200.
- Published NUC switch created system generation 1383 from the task source;
  the same unit, API, container, HTTP, and durable-data checks passed after
  the real switch. The masked `hermes-runtime-smoke` unit is intentionally
  disabled and was not used as a false success signal.
- After app removal, a surviving user-owned Docker sandbox process was found
  and terminated by exact PID; fresh readback shows no Docker.app process or
  user launch agent. The sole residual is root-owned
  `/Library/PrivilegedHelperTools/com.docker.vmnetd` (with its matching launch
  daemon), which cannot be stopped or moved without native administrator
  authorization. OrbStack still reports context `orbstack`, server `29.4.0`.
- `hey nuc-wt test` returned 4 because unrelated pre-existing Mill Docs timer
  jobs failed (canonical checkout merge conflict and TypeScript syntax error);
  none of the affected container units failed in the final activation.

## Reviews

No plan or cross-model review was requested. Coordinator received a structured
partial report in the source task thread.

## Feedback

The earlier live snapshot said Docker Desktop was stopped, but current process
readback showed it running. Runtime ownership must be re-read immediately
before any stop/remove action.

## Remaining work

- Complete macOS admin-authorized removal of the exact Docker Desktop helper
  launchd items and Docker-only root symlinks; do not touch OrbStack or Docker
  data. The app and caskroom are already recoverably in `~/.Trash`.

## Commits

- `e96e228ad` — `feat(containers): use OrbStack and Podman runtimes`; pushed
  directly to `origin/main` and verified local/remote/advertised SHA equality.
