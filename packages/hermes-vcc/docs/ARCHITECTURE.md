# Architecture

System design for hermes-vcc.

## Component Diagram

```
+-----------------------------------------------------------------------+
|                           hermes-vcc                                  |
|                                                                       |
|  +-----------+    +------------+    +----------------+    +---------+ |
|  |  config   |--->|   hooks    |--->| archive        |--->| adapter | |
|  | (YAML)    |    | (install)  |    | (write+compile)|    | (convert| |
|  +-----------+    +-----+------+    +-------+--------+    +---------+ |
|                         |                   |                    ^    |
|                         v                   v                    |    |
|                  +------+-------+    +------+--------+           |    |
|                  | recovery     |    | enhanced_     |           |    |
|                  | (vcc_recover)|    | summary       |-----------+    |
|                  +--------------+    +---------------+                |
|                                                                       |
|  +-------------------------------------------------------------------+
|  |  utils.py                                                         |
|  |  - import_vcc()     Load vendored VCC.py dynamically              |
|  |  - ensure_dir()     Create directories                            |
|  |  - estimate_tokens() Rough byte-pair token estimate               |
|  +-------------------------------------------------------------------+
|                                                                       |
+-----------------------------------------------------------------------+
         |                    |
         v                    v
  +-------------+     +--------------+
  | vendor/     |     | Hermes Agent |
  | VCC.py      |     | (AIAgent)    |
  +-------------+     +--------------+
```

## Module Responsibilities

### config.py

Reads `compression.vcc` from Hermes's `config.yaml`. Produces a typed `VCCConfig` dataclass. All fields have safe defaults so the module works without any configuration file present.

**Dependencies:** PyYAML (optional -- falls back to defaults if missing).

### adapter.py

Stateless format converter. Transforms OpenAI chat-format messages into VCC-compatible Anthropic JSONL records. Handles:

- System messages
- User messages (plain text)
- Assistant messages with text, thinking blocks (`<think>`, `<REASONING_SCRATCHPAD>`), and tool calls
- Tool result messages (with error heuristics)
- Compression summary boundaries (`[CONTEXT COMPACTION]` prefix)

Two-pass design: first pass builds a `tool_call_id -> tool_name` map across all assistant messages, second pass converts each message using that map.

**Dependencies:** None (stdlib only).

### archive.py

Pre-compression archival pipeline. For each compression cycle:

1. Calls `adapter.convert_conversation()` to get JSONL records.
2. Writes `cycle_{N}.jsonl` to the session's archive directory.
3. Invokes `VCC.compile_pass()` to produce `.txt` and `.min.txt` views.
4. Updates `manifest.json` with cycle metadata (timestamp, message count, token estimate).

Also provides `prune_archives()` to enforce retention limits and `get_archive_manifest()` for reading manifests.

All operations are wrapped in try/except. Archival never raises exceptions to the caller.

**Dependencies:** adapter.py, utils.py.

### recovery.py

Agent-facing tool that exposes four actions:

| Action     | Input                   | Output                                              |
| ---------- | ----------------------- | --------------------------------------------------- |
| `list`     | (none)                  | Available cycles with timestamps and message counts |
| `overview` | `archive_id` (optional) | `.min.txt` content for a cycle                      |
| `search`   | `query` (regex pattern) | Matching lines with context from `.txt`             |
| `read`     | `query` (line range)    | Extracted lines from `.txt`                         |

Includes the `VCC_RECOVERY_SCHEMA` (OpenAI function-calling format) for tool registration and `handle_vcc_recover()` as the unified entry point.

Output is capped at 50,000 characters with truncation notice.

**Dependencies:** None (stdlib only, reads files produced by archive.py).

### enhanced_summary.py

Augments LLM compression summaries with VCC structural context:

1. Converts messages to JSONL and compiles with VCC.
2. Reads the `.min.txt` as a structural skeleton.
3. Prepends the skeleton to the serialized conversation turns.
4. Passes the enriched text to the original summary function.

Falls back to plain summary on any VCC failure. The key function `generate_vcc_enhanced_summary()` accepts a generic `Callable[[str], str]` for the LLM summary step, making it testable without API calls.

**Dependencies:** adapter.py, utils.py.

### hooks.py

Non-invasive integration layer. Provides three installers:

- `install_archive_hook(agent, config)` -- Monkey-patches `_compress_context` to archive before compression.
- `install_recovery_tool(agent, config)` -- Adds `vcc_recover` to the agent's tool list and registers a handler.
- `install_all(agent, config=None)` -- Convenience function that loads config and installs all enabled hooks.

Double-patching prevention via `_vcc_archive_wrapped` flag. All hooks are best-effort: failures are logged and silently swallowed.

**Dependencies:** config.py, archive.py, utils.py.

### utils.py

Shared utilities:

- `import_vcc()` -- Dynamic import of `vendor/VCC.py` with caching in `sys.modules`.
- `ensure_dir(path)` -- `mkdir -p` equivalent.
- `estimate_tokens(text)` -- `len(text) // 4` heuristic.
- `vendor_vcc_path()` -- Absolute path to the vendored VCC module.

## Data Flow: Compression Cycle

```
Agent._compress_context(messages, system_message)
         |
         | [VCC hook intercepts]
         |
         v
    (1) adapter.convert_conversation(messages)
         |
         v
    List[dict]  -- VCC JSONL records
         |
         v
    (2) adapter.records_to_jsonl(records)
         |
         v
    str  -- JSONL text
         |
    +----+----+
    |         |
    v         v
  (3a)      (3b)
  Write     VCC.compile_pass()
  .jsonl         |
  to disk   +----+----+
            |         |
            v         v
         .txt      .min.txt
         (full)    (brief)
            |
            v
    (4) Update manifest.json
            |
            v
    (5) Original _compress_context() runs
            |
            v
    Compressed messages returned to agent
```

## Format Transformation Pipeline

```
OpenAI Chat Format          Anthropic JSONL (VCC input)     VCC Output
==================          ===========================     ==========

{"role": "system",    -->   {"type": "system",         -->  [system]
 "content": "..."}          "content": "..."}               You are...

{"role": "user",      -->   {"type": "user",           -->  H: What is...
 "content": "..."}          "message": {
                             "content": "..."}}

{"role": "assistant", -->   {"type": "assistant",      -->  A: VCC is...
 "content": "...",          "message": {                    [tool_use]
 "tool_calls": [...]}        "content": [                   bash({...})
                               {"type": "thinking",
                                "thinking": "..."},
                               {"type": "text",
                                "text": "..."},
                               {"type": "tool_use",
                                "name": "bash",
                                "id": "tc_abc",
                                "input": {...}}
                             ],
                             "id": "msg_xyz"}}

{"role": "tool",      -->   {"type": "user",           -->  [tool_result]
 "content": "...",          "message": {                    Output: ...
 "tool_call_id": "tc"}      "content": [
                               {"type": "tool_result",
                                "tool_use_id": "tc",
                                "content": "...",
                                "is_error": false}
                             ]}}
```

## Archive Directory Structure

```
~/.hermes/vcc_archives/          # Root (configurable via archive_dir)
    session_abc123/              # Per-session subdirectory
        manifest.json            # Cycle metadata index
        cycle_1.jsonl            # Raw JSONL (VCC input)
        cycle_1.txt              # Full transcript (VCC output)
        cycle_1.min.txt          # Brief transcript (VCC output)
        cycle_2.jsonl
        cycle_2.txt
        cycle_2.min.txt
        ...
    session_def456/
        manifest.json
        cycle_1.jsonl
        ...
```

### manifest.json Format

```json
{
  "session_id": "abc123",
  "last_updated": "2026-03-31T10:30:00+00:00",
  "cycles": [
    {
      "id": 1,
      "timestamp": "2026-03-31T10:00:00+00:00",
      "message_count": 45,
      "tokens_estimate": 12400
    },
    {
      "id": 2,
      "timestamp": "2026-03-31T11:30:00+00:00",
      "message_count": 62,
      "tokens_estimate": 18200
    }
  ]
}
```

## Recovery Tool Action Flow

```
vcc_recover(action, query?, archive_id?)
         |
         v
    Resolve archive_dir (config or default)
         |
         v
    Resolve session_dir (session_id or most recent)
         |
         +--- action == "list" ---> Read manifest.json
         |                          Return cycle summaries
         |
         +--- action == "overview" --> Resolve cycle_id
         |                             Read .min.txt (or .txt fallback)
         |                             Return capped content
         |
         +--- action == "search" ---> Resolve cycle_id
         |                            Compile regex from query
         |                            Scan .txt line by line
         |                            Return matches with context
         |
         +--- action == "read" -----> Resolve cycle_id
                                      Parse line range from query
                                      Extract lines from .txt
                                      Return numbered lines
```
