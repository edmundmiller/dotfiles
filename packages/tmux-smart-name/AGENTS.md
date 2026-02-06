# tmux-smart-name

Smart tmux window naming with AI agent status detection. TypeScript, zero deps, bundled via bun.

## Architecture

```
src/
├── index.ts      # CLI entry — rename, --status, --menu, --check-attention
├── tmux.ts       # subprocess helpers (list-sessions, capture-pane, etc.)
├── process.ts    # process tree detection (AGENT_PROGRAMS, WRAPPERS, aliases)
├── status.ts     # pane content → status icon (error/waiting/busy/idle/unknown)
├── naming.ts     # window name builder (program + path, trim w/ tmux color awareness)
└── menu.ts       # agent management menu (display-menu generation)
scripts/
└── smart-name.sh # shell wrapper — hook registration, init, delegates to node dist/index.js
```

## Adding a New Agent

1. Add binary name to `AGENT_PROGRAMS` in `src/process.ts`
2. If it has alternate binary names, add to `AGENT_ALIASES` (e.g. `oc` → `opencode`)
3. Add a test case in `tests/process.test.ts`
4. Run `bun test`

## How AGENT_PROGRAMS Was Populated

Combination of:

1. **Local binary scan** — `which` for known agent binaries on this machine
2. **Known terminal AI agents** as of early 2025 — manually curated from common tools

### To discover new agents

```bash
# Check what's installed locally
for cmd in opencode oc claude amp pi aider goose codex copilot mentat cody gemini zed cursor; do
  which "$cmd" 2>/dev/null && echo "  found: $cmd"
done

# Check what's running in tmux right now (child processes of shells)
tmux list-panes -a -F '#{pane_pid}' | while read pid; do
  ps -a -oppid=,command= | awk -v p="$pid" '$1==p {print $2}'
done | sort -u

# GitHub trending CLI tools tagged "ai-agent" or "coding-assistant"
# https://github.com/topics/ai-coding-assistant
# https://github.com/topics/terminal-ai
```

### Current list rationale

| Agent        | Binary           | Notes                                 |
| ------------ | ---------------- | ------------------------------------- |
| Claude Code  | `claude`         | Anthropic CLI                         |
| OpenAI Codex | `codex`          | OpenAI CLI agent                      |
| Gemini CLI   | `gemini`         | Google CLI                            |
| Amp          | `amp`            | Sourcegraph agent                     |
| OpenCode     | `opencode`, `oc` | TUI for LLM coding                    |
| pi           | `pi`             | Node-based, runs under `node` wrapper |
| Aider        | `aider`          | Python, pair programming              |
| Goose        | `goose`          | Block (fka Square) agent              |
| Mentat       | `mentat`         | AbanteAI                              |
| Cline        | `cline`          | Terminal mode of VS Code extension    |
| Cursor       | `cursor`         | Terminal agent mode                   |
| Zed          | `zed`            | Zed editor AI features                |
| Warp         | `warp`           | Warp terminal AI                      |
| Continue     | `continue`       | Continue.dev CLI                      |
| Sweep        | `sweep`          | GitHub PR agent                       |
| GPT Engineer | `gpt-engineer`   |                                       |
| GPT Pilot    | `gpt-pilot`      |                                       |
| Plandex      | `plandex`        | Plan-driven agent                     |
| Devon        | `devon`          |                                       |
| Roo          | `roo`            | Roo Code CLI                          |

## Hook System

- smart-name.sh hooks use array index `[0]`
- theme.conf hooks use array index `[100]`
- This prevents mutual clobbering

## Build

```bash
bun test              # 72 tests
bun build src/index.ts --outdir dist --target node
```

Nix build bundles to single `dist/index.js`, patches `node` to nix store path.
