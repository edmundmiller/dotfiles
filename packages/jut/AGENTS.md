# jut - Agent Documentation

## Purpose

Opinionated human + agentic framework around Jujutsu (jj). Not a replacement — a thin layer that adds JSON output, workflow composition, and agent-friendly conventions. Drop into raw `jj` anytime for interactive work.

## Architecture

- **Rust binary** (`clap` CLI) — `src/main.rs` entry point
- **jj-lib** for reads (repo discovery, commit data, bookmarks, short IDs) — `src/repo.rs`
- **jj CLI** for mutations (describe, new, squash) — avoids complex transaction handling
- **gh CLI** for PR creation

```
src/
├── main.rs          # CLI entry, dispatch
├── args.rs          # Clap args, OutputFormat, global flags
├── output.rs        # OutputChannel (text/json formatting)
├── repo.rs          # jj-lib repo handle + jj CLI runner
├── stack.rs         # Stack analysis, revision queries
├── id/mod.rs        # Short ID generation
└── command/
    ├── status.rs    # Default command (bare `jut`)
    ├── log.rs       # Structured JSON log
    ├── diff.rs / show.rs
    ├── commit.rs    # describe + new in one step
    ├── branch.rs    # new rev + bookmark, supports --stack
    ├── rub.rs       # Universal combine primitive
    ├── squash.rs / reword.rs / absorb.rs
    ├── push.rs / pull.rs / pr.rs
    ├── discard.rs   # unified restore/abandon
    ├── undo.rs / oplog.rs
    └── skill.rs     # Agent skill management
```

## Key Design Decisions

- **Reads via jj-lib, writes via jj CLI.** Working copy snapshots and transaction handling are complex; the CLI handles them correctly. Reads (repo discovery, commit data, bookmarks, short IDs) use jj-lib directly for speed and structured access.
- **Default command is `status`** — bare `jut` shows workspace overview.
- **Default rub** — `jut <source> <target>` (no subcommand) dispatches to `rub`.
- **`--json` and `--status-after`** are global flags, not per-subcommand.
- **No interactive commands.** `split`, `resolve`, `rebase -i` — use `jj` directly.

## The Agent Problem

Models have seen millions of git workflows but almost zero jj workflows. They default to git mental models:
- "make change → commit → make change → commit" (linear, git-style)
- Instead of jj's "working copy IS a commit you describe and evolve"
- They don't grok `jj new` (create child) vs `git commit` (checkpoint)

This causes agents to create one-off commits instead of proper stacks. The fix is:
1. **`--status-after` on every mutation** — forces agents to see state and react, not plan from memory
2. **The skill** (`jut skill install`) — teaches the jj model, not just command mappings
3. **The eval harness** (`skill/eval/`) — measures skill compliance, finds failure modes

See `docs/agent-design.md` for the full philosophy.

## Nix Packaging

- `default.nix` uses `rustPlatform.buildRustPackage` with `cargoLock.lockFile`
- `doCheck = false` — integration tests need a real jj repo + git (sandbox-incompatible)
- Wraps binary with `jujutsu` and `gh` in PATH
- Installed via `modules/shell/jj/default.nix` as `pkgs.my.jut`

## Building & Testing

```bash
nix build .#jut                 # Nix build
cd packages/jut && cargo build  # Dev build
cargo test                      # Integration tests (needs jj + git in PATH)
```

## Skill & Eval

```bash
jut skill show                  # Print SKILL.md
jut skill install               # Install to .agents/skills/jut/
jut skill install --global      # Install to ~/.pi/agent/skills/ + ~/.claude/skills/
cd skill/eval && pnpm run eval  # Run promptfoo evals (Claude + Codex)
```

## Related Files

- `modules/shell/jj/default.nix` — installs jut alongside jj
- `config/jj/config.toml` — jj config (jut reads jj's config)
- `docs/but-comparison.md` — command mapping vs GitButler CLI
- `docs/agent-design.md` — design philosophy and agent failure modes
- `skill/SKILL.md` — the agent skill (embedded in binary)
- `skill/eval/` — promptfoo eval harness
