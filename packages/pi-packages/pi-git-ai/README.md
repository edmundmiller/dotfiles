# pi-git-ai

[Git AI](https://usegitai.com) integration for [pi](https://github.com/mariozechner/pi-coding-agent) — tracks AI-generated code authorship via `git-ai checkpoint`.

## What it does

Hooks into pi's tool execution lifecycle to call `git-ai checkpoint agent-v1` before and after file edits:

1. **Before edit** — marks any pending uncommitted changes as human-authored
2. **After edit** — marks the AI's changes with full transcript, model name, and session ID

Supports `edit`, `write`, and `apply_patch` tool calls.

## Requirements

- [git-ai CLI](https://usegitai.com/docs/cli/installation) installed and on `$PATH`
- A git repository (git-ai operates on git-tracked files)

Silently skips if `git-ai` is not installed — no errors, no noise.

## Install

```bash
pi settings set packages '["pi-git-ai"]'
```

Or add to your pi `settings.json`:

```json
{
  "packages": ["pi-git-ai"]
}
```

## How it works

Uses the `agent-v1` preset to pass structured data to git-ai via stdin:

- **Human checkpoint**: `{type: "human", repo_working_dir, will_edit_filepaths}`
- **AI checkpoint**: `{type: "ai_agent", repo_working_dir, edited_filepaths, transcript, agent_name, model, conversation_id}`

The transcript includes `user`, `assistant`, `thinking`, and `tool_use` messages. Tool results are excluded per git-ai spec.

After committing, use `git-ai blame` to see AI vs human authorship on each line.

## License

MIT
