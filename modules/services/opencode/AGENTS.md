# OpenCode service

NUC runs a Podman OpenCode container, distinct from the workstation V2 CLI
module. Backend port 4096 is loopback-only; `svc:opencode` exposes
`https://opencode.cinnamon-rooster.ts.net` over Tailscale HTTPS.

`default.nix` owns image/port/project mount options. The container runs as root
inside its namespace; `projectDir` is mounted at `/app`. Inspect
`podman-opencode.service`, `opencode-tailscale-serve.service`, their journals,
and `tailscale status --json` service proxies.

VIP definitions and ACL grants belong to the tailnet repo, not manual console
approval. A deploy timeout does not establish that activation failed; inspect
target units before retrying a state change.
