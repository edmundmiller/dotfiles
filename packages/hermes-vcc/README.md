# hermes-vcc

**Lossless conversation archiving with deterministic VCC compression summaries for AI agents.**

Version 0.2.0

---

## Motivation

Long-running AI agent sessions hit context window limits. The standard fix is LLM-generated summaries that discard tool outputs, error messages, and reasoning chains. This is lossy and expensive.

**hermes-vcc** takes a different approach based on the VCC paper: the summary _is_ the `.min.txt` compiled by VCC. No LLM call. Deterministic, instant, free. The full conversation is archived to disk so the agent can recover any detail by reading files directly.

VCC's `.min.txt` outperforms LLM-generated summaries on AppWorld benchmarks (+1-4 percentage points accuracy, ~60% fewer tokens).

## How It Works

1. Before each compression, the full conversation is archived as JSONL and compiled to VCC views (`.txt`, `.min.txt`).
2. The `.min.txt` replaces the LLM summary. No API call, no cost, no latency.
3. When the agent needs compressed-out details, it reads the archive files directly or runs `VCC.py --grep`.

```
Agent Session
     |
[context pressure]
     |
     v
+------------------+     +-------------------+
| ARCHIVE          |     | SUMMARY           |
|                  |     |                   |
| messages -> JSONL |     | messages -> VCC   |
| VCC compile:     |     | .min.txt IS the   |
|   .txt (full)    |     | compression       |
|   .min.txt (brief)|    | summary           |
+------------------+     +-------------------+
     |
     v
vcc_archives/
  session_abc/
    cycle_1.jsonl        # lossless record
    cycle_1.txt          # full readable view
    cycle_1.min.txt      # structural brief
    cycle_2.jsonl
    cycle_2.txt
    cycle_2.min.txt
    manifest.json
```

## Recovery

There is no special recovery tool. The agent recovers details the same way it reads any file:

- **List archives:** Read `manifest.json` or use `list_archives()` to find what cycles exist.
- **Read summaries:** Open `cycle_N.min.txt` for structural overview, `cycle_N.txt` for full detail.
- **Search:** Run `python vendor/VCC.py --grep "pattern" cycle_N.txt` for regex search across archives.

## Modules

| Module                | Purpose                                                                        |
| --------------------- | ------------------------------------------------------------------------------ |
| `adapter.py`          | Convert OpenAI chat-format messages to VCC-compatible Anthropic JSONL          |
| `archive.py`          | Write timestamped JSONL snapshots and compile VCC views per compression cycle  |
| `enhanced_summary.py` | `compile_to_brief(messages)` — compile messages to `.min.txt` content directly |
| `hooks.py`            | `install(agent)` — patch archive + summary hooks onto a running Hermes agent   |
| `config.py`           | Load `compression.vcc` from Hermes `config.yaml` with safe defaults            |
| `utils.py`            | VCC import helper, token estimation, directory utilities                       |
| `recovery.py`         | `list_archives(archive_dir)` — find and list available archive cycles          |

## Quick Start

### Install

```bash
pip install hermes-vcc
# or from source:
pip install -e /path/to/hermes-vcc
```

### Configure

Add to `~/.hermes/config.yaml`:

```yaml
compression:
  vcc:
    enabled: true
    archive_dir: ~/.hermes/vcc_archives
    retain_archives: 10
```

| Key               | Type | Default                  | Description                                    |
| ----------------- | ---- | ------------------------ | ---------------------------------------------- |
| `enabled`         | bool | `true`                   | Master switch for VCC                          |
| `archive_dir`     | path | `~/.hermes/vcc_archives` | Root directory for archives                    |
| `retain_archives` | int  | `10`                     | Max archive cycles per session (oldest pruned) |

### Automatic Operation (Hermes)

```python
from hermes_vcc.hooks import install
install(agent)  # patches archive + summary hooks
```

After this call:

- Every compression cycle archives the full conversation first.
- The LLM summary is replaced with VCC `.min.txt` output.
- Falls back to the original LLM summary if VCC compilation fails.

No other code changes required.

## Standalone Usage

```python
from hermes_vcc.adapter import convert_conversation, records_to_jsonl

messages = [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "What is VCC?"},
    {"role": "assistant", "content": "VCC is the Virtual Context Compiler..."},
]

records = convert_conversation(messages)
jsonl = records_to_jsonl(records)
```

Archive with VCC compilation:

```python
from pathlib import Path
from hermes_vcc.archive import archive_before_compression

session_dir = archive_before_compression(
    messages=messages,
    session_id="my-session",
    archive_dir=Path("./archives"),
    compression_cycle=1,
)
# Produces: ./archives/my-session/cycle_1.jsonl, .txt, .min.txt, manifest.json
```

Compile to `.min.txt` directly:

```python
from hermes_vcc.enhanced_summary import compile_to_brief

brief = compile_to_brief(messages)
# Returns the .min.txt content as a string, or None on failure
```

List archives:

```python
from hermes_vcc.recovery import list_archives

print(list_archives(Path("./archives")))
```

## Project Structure

```
hermes_vcc/
    __init__.py          # Version (0.2.0)
    adapter.py           # OpenAI -> VCC JSONL format conversion
    archive.py           # Pre-compression archival pipeline
    enhanced_summary.py  # compile_to_brief() — messages to .min.txt
    hooks.py             # install() — non-invasive agent integration
    config.py            # Configuration from Hermes config.yaml
    utils.py             # VCC import, token estimation, directory helpers
    recovery.py          # list_archives() — find archived cycles

vendor/
    VCC.py               # Vendored VCC compiler (upstream: lllyasviel/VCC)

tests/
    conftest.py          # Shared fixtures
    test_adapter.py
    test_archive.py
    test_enhanced_summary.py
    test_hooks.py
    test_recovery.py
    test_roundtrip.py
```

## Academic Context

Based on the **Virtual Context Compiler (VCC)** by Lvmin Zhang et al. (Stanford University / ControlNet). VCC compiles conversation transcripts into compressed, view-oriented representations that preserve structural information while reducing token count.

Key results from the VCC paper (AppWorld benchmarks):

- **+1 to +4 pp** improvement in task completion accuracy vs. raw transcripts
- **~60% fewer tokens** than full conversation logs
- The `.min.txt` view captures tool call patterns, decision points, and error recovery flows

**Reference:** Lvmin Zhang, _Virtual Context Compiler_, Stanford University / ControlNet. [GitHub: lllyasviel/VCC](https://github.com/lllyasviel/VCC)

## Contributing

```bash
git clone https://github.com/nousresearch/hermes-vcc.git
cd hermes-vcc
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
pytest
```

- Python 3.11+
- Type hints on all public APIs
- Tests required for new functionality
- No exceptions may propagate from archive/hook code to the agent

## License

Apache License 2.0. See [LICENSE](LICENSE).

## Acknowledgments

- **Lvmin Zhang** (Stanford / ControlNet) for the Virtual Context Compiler and the research demonstrating its effectiveness on agent benchmarks.
- **Nous Research** for the Hermes agent framework.
