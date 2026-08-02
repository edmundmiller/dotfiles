# Worklog: omp-mcp-cleanup

Status: active

## Objective

Separate OMP MCP registrations into a minimal shared default and a Seqeratop-only overlay. Preserve each MCP’s behavior while removing unnecessary default exposure. Stop when the rendered maps and OMP startup prove the intended split; do not activate Seqeratop from another host.

## Decisions

- Scope is OMP only. Codex, Hermes, and Claude Code are explicitly deferred.
- The active host is MacTraitor-Pro, not Seqeratop. Host-specific activation is out of scope here.
- The supplied checkout is a concurrently modified Codex worktree. A clean clone from `origin/main` isolates this task.
- OMP natively prioritizes `~/.omp/agent/mcp.json` over inherited Claude/Codex MCP sources. It currently has no Nix-managed native MCP file.
- Keep only FFF as the shared coding MCP. Explicitly block inherited `strava-mcp`, `cogny`, and `computer-use`; each is non-coding or already disabled, and none is cached as used by OMP.
- No authoritative Seqeratop-specific MCP registration exists. The new host overlay remains empty until a work MCP is deliberately added; do not promote transient `.omp/wt` state.

## Evidence

- OMP config schema confirms native user MCP config support; Context7 docs confirm native precedence and no merge between duplicate names.
- Current inherited configs: Claude exposes FFF; Codex exposes FFF, Strava, Cogny, and a disabled Computer Use server. OMP's cache contains only Context7 metadata.
- `bash modules/agents/omp/test-config-yml.sh` and `bash modules/agents/omp/test-mcp-json.sh` pass.
- `hey check --worktree` passes all Darwin-compatible checks. `sudo darwin-rebuild switch --flake .` activated successfully on MacTraitor-Pro.
- Deployed `~/.omp/agent/mcp.json` contains only FFF and the three explicit blocks. `omp -p --no-session` used FFF to resolve `config/omp/config.yml`.

## Reviews

- Plan review blocked: the default Claude reviewer requires authentication; the xAI selector is not an ACP agent; installed Gemini has no `acp` mode. The policy is a reversible, data-free MCP allowlist, so proceed with focused local validation and retain this blocker for landing.
- Landing review blocked by the same unavailable Claude ACP authentication.

## Feedback

- `hey agent-start --help` emits a Nu deprecation warning for `str downcase`; unrelated to this task.

## Remaining work

- Rebase and publish the isolated OMP change, prove remote equality, then create its annotated task tag.

## Commits

- `feat(omp): manage MCP defaults` is ready for remote landing. Final revision is recorded in the completion receipt.
