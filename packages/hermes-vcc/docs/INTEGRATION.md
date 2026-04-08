# Hermes Integration Guide

How to integrate hermes-vcc with the Hermes agent for automatic conversation archiving and recovery.

## Prerequisites

1. **Python 3.11+** (same as Hermes agent requirement).
2. **Hermes agent** installed and running (the `AIAgent` class with `_compress_context` method).
3. **hermes-vcc** installed:
   ```bash
   pip install hermes-vcc
   # or from source:
   pip install -e /path/to/hermes-vcc
   ```
4. **PyYAML** (already a Hermes dependency; also a hermes-vcc dependency).

## Config.yaml Additions

Add the following section to `~/.hermes/config.yaml`:

```yaml
compression:
  # ... existing compression settings ...

  vcc:
    enabled: true

    # Where to store conversation archives.
    # Default: ~/.hermes/vcc_archives
    archive_dir: ~/.hermes/vcc_archives

    # Use VCC .min.txt to enrich LLM compression summaries.
    # Produces better summaries at no extra API cost.
    enhanced_summary: true

    # Register the vcc_recover tool so the agent can query archives.
    recovery_tool: true

    # Maximum archive cycles to retain per session.
    # Older cycles are pruned automatically.
    retain_archives: 10
```

### Minimal Configuration

If you just want archiving with all defaults:

```yaml
compression:
  vcc:
    enabled: true
```

All other settings default to sensible values (see Configuration Reference in [README.md](../README.md)).

## Hook Installation

### Automatic (recommended)

Call `install_all()` during agent startup, after the `AIAgent` instance is created:

```python
from hermes_vcc.hooks import install_all

# After agent is initialized:
results = install_all(agent)
# results == {"archive_hook": True, "recovery_tool": True}
```

This:

1. Loads `compression.vcc` from `~/.hermes/config.yaml`.
2. Monkey-patches `agent._compress_context` to archive before each compression.
3. Adds `vcc_recover` to `agent.tools` and `agent.valid_tool_names`.
4. Registers a handler at `agent._vcc_recover_handler`.

### Manual (selective installation)

If you want finer control:

```python
from hermes_vcc.config import load_config
from hermes_vcc.hooks import install_archive_hook, install_recovery_tool

config = load_config()

# Install only the archive hook:
install_archive_hook(agent, config)

# Or only the recovery tool:
install_recovery_tool(agent, config)
```

### Wiring the Recovery Tool Handler

After `install_recovery_tool()` runs, the agent has:

- `agent.tools` -- updated with `VCC_RECOVERY_SCHEMA`
- `agent.valid_tool_names` -- updated with `"vcc_recover"`
- `agent._vcc_recover_handler` -- a callable `(action, cycle_id=None) -> str`

When the agent receives a `vcc_recover` tool call, route it through the handler:

```python
# In your tool dispatch logic:
if tool_name == "vcc_recover":
    result = agent._vcc_recover_handler(
        action=args["action"],
        cycle_id=args.get("cycle_id"),
    )
```

The handler resolves the session directory from `agent.session_id` and returns a human-readable string.

### Using the Standalone Recovery Module

For more control (e.g., cross-session queries), use `hermes_vcc.recovery.handle_vcc_recover()` directly:

```python
from pathlib import Path
from hermes_vcc.recovery import handle_vcc_recover

result = handle_vcc_recover(
    action="search",
    query="database.*migration",
    archive_dir=Path("~/.hermes/vcc_archives").expanduser(),
    session_id="session_abc123",
)
```

## Threshold Optimization with VCC Safety Net

With VCC archiving in place, you can safely lower your compression thresholds. The rationale: since nothing is truly lost (the agent can recover any detail via `vcc_recover`), there is no penalty for compressing earlier and more aggressively.

### Recommended Settings

| Setting                         | Without VCC                 | With VCC                    | Why                                 |
| ------------------------------- | --------------------------- | --------------------------- | ----------------------------------- |
| Compression trigger             | 80% of context window       | 60-70%                      | Compress earlier to stay lean       |
| Summary aggressiveness          | Conservative (keep details) | Aggressive (keep structure) | Details recoverable via VCC         |
| Max messages before compression | 100+                        | 50-80                       | More frequent, smaller compressions |

### Example config.yaml

```yaml
compression:
  # Trigger compression at 65% of context window
  threshold: 0.65

  # Aggressive summarization is safe with VCC backup
  strategy: aggressive

  vcc:
    enabled: true
    enhanced_summary: true
    recovery_tool: true
    retain_archives: 10
```

## Troubleshooting

### VCC hooks not installing

**Symptom:** `install_all()` returns `{"archive_hook": False, "recovery_tool": False}`.

**Checks:**

1. Is `compression.vcc.enabled` set to `true` in config.yaml?
2. Does the agent instance have a `_compress_context` method? (Required for the archive hook.)
3. Does the agent instance have a `tools` attribute (list)? (Required for the recovery tool.)

Enable debug logging to see detailed messages:

```python
import logging
logging.getLogger("hermes_vcc").setLevel(logging.DEBUG)
```

### Archives not being created

**Symptom:** `~/.hermes/vcc_archives/` is empty after compression events.

**Checks:**

1. Is the archive hook actually installed? Check `hasattr(agent._compress_context, '_vcc_archive_wrapped')`.
2. Is the agent's `session_id` attribute set? If `None`, archives go to `unknown/`.
3. Check permissions on the archive directory.
4. Look for warnings in the `hermes_vcc` logger -- all archive failures are logged as warnings.

### VCC compile_pass failing

**Symptom:** `.jsonl` files are created but `.txt` and `.min.txt` are missing.

**Checks:**

1. Is `vendor/VCC.py` present in the hermes-vcc package directory?
2. Does VCC.py have its dependencies available? (It is a standalone script but may require specific Python features.)
3. Check for `VCC compile_pass failed` warnings in the log.

The archive pipeline is resilient -- JSONL files are still written and the manifest is still updated even if VCC compilation fails. The recovery tool can fall back to reading raw JSONL.

### Recovery tool returning "No VCC archives found"

**Symptom:** Agent calls `vcc_recover(action="list")` and gets an empty response.

**Checks:**

1. Verify the archive directory exists: `ls ~/.hermes/vcc_archives/`
2. Check that the session ID matches: the recovery handler uses `agent.session_id` to find the subdirectory.
3. For cross-session queries, pass `session_id` explicitly.

### Enhanced summary not using VCC skeleton

**Symptom:** Compression summaries look the same with and without VCC.

**Checks:**

1. Is `compression.vcc.enhanced_summary` set to `true`?
2. Check for `VCC compilation failed during enhanced summary` warnings.
3. VCC compilation requires at least a few messages -- very short conversations may not produce a useful `.min.txt`.

### Disk space growing

The `retain_archives` setting controls how many cycles are kept per session. Set it lower if disk usage is a concern:

```yaml
compression:
  vcc:
    retain_archives: 5 # Keep only the 5 most recent cycles
```

Old `.jsonl`, `.txt`, and `.min.txt` files are automatically deleted when the cycle count exceeds this limit.
