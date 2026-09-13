# OMP wiring

OMP is isolated from Pi by its wrapper:

```sh
PI_CONFIG_DIR=.omp
PI_CODING_AGENT_DIR=$HOME/.omp/agent
PI_PERMISSION_SYSTEM_CONFIG_PATH=$HOME/.omp/agent/extensions/pi-permission-system/config.json
```

`config/omp/` owns config/commands/rules; the module renders MCP and LSP config
with host overrides. Other runtime state remains OMP-owned. Activation clears
cached MCP metadata so removed servers cannot reappear from `agent.db`.

## Integration contracts

- LSP selects pinned Effect LS for projects using `@effect/tsgo`, standard TS LS
  otherwise. Nextflow uses the Nix launcher; Vale uses pinned binaries and each
  project's `.vale.ini`.
- Plannotator and browser-native registrars load eagerly; full graphs load on
  use. Preserve command/tool schemas, lifecycle replay, host import bridges,
  disabled original extension IDs, and the browser guard.
- Darwin review-loop wiring uses `ctx.hasUI` and builds the Glimpse host skipped
  by the plugin installer. Local pi-herdr/pi-hunk provide review integrations.
- Seqera MCP OAuth is runtime-owned; `/mcp reauth seqera` follows activation.

## Instructions and hooks

The global core is `config/agents/core.md` (220-word limit). TTSR rules use
`condition` / `astCondition`; each has positive and negative cases in
`tests/fixtures/omp-ttsr-rules.json`. Non-aborting reminders use
`interruptMode: "never"`. Authority is enforced by deterministic policy, not
TTSR alone. [ADR 0010](../../../docs/adr/0010-omp-ttsr-thin-agent-harness.md)
owns placement. Slash templates need explicit Home Manager links; RPC
`get_available_commands` proves discovery without a model call.

There is no project stop gate or `completion_check` tool. Run `hey check` for
task-owned edits; read-only tasks and honest limitation reports may finish
without forced continuations. Keep `unexpectedStopDetection: smart`.

The permission guard protects the shared Pi/OMP policy and runtime symlink.
Its `GUIDANCE_LINES` explains the blocked operation and the appropriate source
for OMP-only, module, or explicitly requested shared-policy changes.

## Checks and model routing

Choose the affected `test-config-yml.sh`, `test-mcp-json.sh`,
`test-mcp-host-config.sh`, or `test-lsp-config.sh` here. Config tests use an
isolated OMP home and reject unknown keys/warnings; host tests build resolved
Darwin config. Validation routing tests: `python3 -m unittest tests/test_validation.py`.
TTSR tests:
`python3 -m unittest tests/test_omp_ttsr_rules.py` and `omp ttsr list --json`.

Per-host providers/roles are declared in `hosts/*/default.nix`; shared defaults
are in `config/omp/config.yml`. Smol precedence is `--smol` > `PI_SMOL_MODEL` >
rendered config; explicit commit role wins over smol. Provider IDs must exist
in `omp models <provider>` on that host. Use `omp-model-config` for role changes
and [docs](docs/README.md) for detailed runtime investigations.
