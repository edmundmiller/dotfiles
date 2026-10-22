---
purpose: Record the host-owned MCP catalog and agent adapter decision.
applies_to: Host MCP selection and Pi, OMP, Claude, Codex, OpenCode V2, and Amp configuration.
entrypoint: Edit modules.agents.mcp in the host configuration.
verification: Run uv run --with json5 --with tomlkit python -m unittest tests.test_agent_mcp.
update_when: MCP ownership, adapters, credential handling, or host selection changes.
---

# ADR 0013: Host-owned agent MCP

## Status

Accepted, 2026-10-15. This decision does not authorize host activation.

## Decision

Use one host catalog in `modules.agents.mcp`, implemented by
[`modules/agents/mcp/default.nix`](../../modules/agents/mcp/default.nix).
Shared definitions live in [`config/agents/mcp.nix`](../../config/agents/mcp.nix).
Hosts select enabled servers and agent targets. Server definitions describe
stdio commands or HTTP URLs, non-secret subprocess environment values, bearer
token environment variable names, and optional per-agent exclusions.
The generated `~/.config/agents/mcp.json` is the reconciliation manifest, not
another hand-maintained server inventory.

Use six per-agent adapters in
[`config/agents/reconcile_mcp.py`](../../config/agents/reconcile_mcp.py).
Each agent connects directly to its servers; there is no shared MCP gateway.
Native adapters avoid running another service and preserve each client's OAuth
flow. A gateway would share connection and authentication failures across agents.
Seed-once files were rejected because later host selections would not take effect;
read-only links were rejected because Pi writes MCP settings in place.

| Adapter           | Writable target                               | Server key       |
| ----------------- | --------------------------------------------- | ---------------- |
| Pi 1.0 native MCP | `~/.pi/agent/mcp.json`                        | `mcpServers`     |
| OMP               | `~/.omp/agent/mcp.json`                       | `mcpServers`     |
| Claude            | `~/.claude.json`                              | `mcpServers`     |
| Codex             | `~/.codex/config.toml`                        | `mcp_servers`    |
| OpenCode V2       | `~/.config/opencode2/opencode/opencode.jsonc` | `mcp.servers`    |
| Amp               | `~/.config/amp/settings.json`                 | `amp.mcpServers` |

Amp is an explicit target via `modules.agents.mcp.agents.amp = true`.
Other targets default to their runtime module's enable flag. Amp uses an existing
`settings.jsonc` instead when present; having both settings files is an error.
Hermes runtime and profile configuration intentionally belongs to
`agents-workspace`, outside this dotfiles owner's adapter set.

## Writable reconciliation

After an authorized activation, reconcile catalog-owned entries into writable
agent files instead of replacing whole files with Nix store links. Preserve
unrelated settings, non-catalog MCP servers, and runtime-owned authentication.
Track managed server names in `~/.local/state/agents/mcp-managed.json` so removed
servers and disabled targets lose only managed registrations. On first adoption,
catalog names replace old agent-specific definitions with the same names.
Before Home Manager removes obsolete links, convert Nix store config symlinks
to mode-0600 regular files, preserving their contents. Reconcile after runtime
bootstrap. Disabling the shared module reconciles an empty manifest so it also
removes previous registrations. Unrelated user symlinks are refused.
JSON/JSONC output is rewritten as JSON, so preservation applies to data, not
comments or formatting. Codex uses a TOML-aware editor. Pi registrations use
codemode exposure and reconciliation enables `autoEnableCodemode`.
OMP can inherit servers from other clients. Its adapter also reconciles
catalog names in `disabledServers` and `enabledServers`, so an exclusion cannot
reappear through discovery. Unrelated names in those lists remain user-owned.

Authentication remains local to the runtime or credential launcher. The GitHub
stdio launcher reads `gh auth token` at process start, exports it only to the
server process as `GITHUB_PERSONAL_ACCESS_TOKEN`, and starts
`github-mcp-server stdio`. Do not put resolved credentials in the catalog,
generated manifest, Nix store, or command arguments. HTTP bearer registrations
refer to environment variable names; adapters render each client's syntax.

Codex's `homeAssistantMcp` remains a credential-specific `codex-ha` launcher.
It resolves the configured 1Password reference into child-only `HASS_TOKEN`.
Register the server separately in the host catalog as `homeassistant`, with
`bearerTokenEnv = "HASS_TOKEN"`. Enabling the launcher alone does not register
the server. OAuth login and token refresh remain runtime-owned.

## Consequences and verification

Hosts can choose different server sets without maintaining separate inventories
for every agent. Adapters own schema differences, while runtimes retain settings
and authentication. A client schema or environment interpolation change requires
adapter verification, not a gateway change.

The focused source test is
`uv run --with json5 --with tomlkit python -m unittest tests.test_agent_mcp`.
Use isolated homes for reconciliation checks. Source checks do not prove live
OAuth, inherited credentials, or remote server connectivity. Applying the
manifest to a live home or activating a host requires separate authorization.

To reverse a server selection, revert the host edit and activate again. Removing
the module's source entirely bypasses cleanup; first activate with `enable = false`.
Pre-migration generations expect read-only files and are not a rollback mechanism
for writable runtime state. Back up agent configs before the first activation.

## References

- [Originating discussion](https://ampcode.com/threads/T-01a13ef0-d290-75a9-ae9b-cc60c14285c2).
