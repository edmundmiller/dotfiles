# pi-context-repo

Git-backed persistent memory filesystem for [pi](https://github.com/mariozechner/pi-coding-agent) agents, inspired by [Letta Code's Context Repositories](https://www.letta.com/blog/context-repositories).

## Install

```bash
pi install /path/to/pi-context-repo
# or after publishing:
pi install npm:pi-context-repo
```

## How it works

Memory is stored as markdown files with YAML frontmatter in `.pi/memory/` (a separate git repo inside your project).

- **`system/`** files are pinned to the system prompt every turn
- **Other files** appear in the tree — the agent reads them on demand (progressive disclosure)
- **Git versioning** tracks all memory changes with informative commits
- **Frontmatter** enforces `description`, `limit`, and optional `read_only` per file

### Scaffolded structure (auto-created on first run)

```
.pi/memory/
├── system/
│   ├── persona.md  — Agent identity and behavior
│   └── user.md     — User preferences and context
└── reference/
    └── README.md   — How to use reference/
```

## Tools

| Tool            | Description                                                    |
| --------------- | -------------------------------------------------------------- |
| `memory_write`  | Write/update a memory file (auto-stages, respects `read_only`) |
| `memory_commit` | Commit staged changes with a descriptive message               |
| `memory_search` | Search memory files by content (`git grep`)                    |
| `memory_log`    | Show recent commit history                                     |

## Commands

| Command        | Description                           |
| -------------- | ------------------------------------- |
| `/memory`      | Show tree, status, and recent history |
| `/memory-init` | Re-scaffold memory directory          |

## UI

- **Status widget** shows uncommitted change count in pi footer
- **System prompt** includes dirty reminder when changes need committing

## Design

Adapted from Letta Code's [memoryGit.ts](https://github.com/letta-ai/letta-code/blob/main/src/agent/memoryGit.ts) and [Context Repositories](https://docs.letta.com/letta-code/memory) concept:

- Files as memory units with metadata frontmatter
- `system/` subdir always loaded (like Letta's pinned memory blocks)
- File tree always visible for on-demand loading
- Git for versioning, history, and eventual multi-agent sync
- Natural memory application — no "I remember that..." narration
