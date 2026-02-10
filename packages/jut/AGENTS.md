# jut - Agent Documentation

## Purpose

GitButler-inspired CLI for Jujutsu (jj). Mirrors the UX patterns of [`but` (GitButler CLI)](https://gitbutler.com/) — short IDs, `--json` output, `rub` primitive, `--status-after` — but targets jj instead of git. PR creation via `gh` (no GitHub app required).

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
├── id/mod.rs        # Short ID generation
└── command/
    ├── mod.rs
    ├── status.rs    # Default command (no subcommand)
    ├── diff.rs
    ├── show.rs
    ├── commit.rs    # describe + new
    ├── rub.rs       # Universal combine primitive
    ├── squash.rs
    ├── reword.rs
    ├── push.rs
    ├── pull.rs
    ├── pr.rs        # gh CLI integration
    ├── discard.rs   # restore/abandon
    ├── undo.rs
    ├── absorb.rs
    └── log.rs
```

## Key Design Decisions

- **Reads via jj-lib, writes via jj CLI.** Working copy snapshots and transaction handling are complex; the CLI handles them correctly. Migrating writes to jj-lib is tracked in `dotfiles-wkch.6` through `dotfiles-wkch.10`.
- **Default command is `status`** — bare `jut` shows workspace overview.
- **Default rub** — `jut <source> <target>` (no subcommand) dispatches to `rub`.
- **`--json` and `--status-after`** are global flags on `Args`, not per-subcommand.

## Nix Packaging

- `default.nix` uses `rustPlatform.buildRustPackage` with `cargoLock.lockFile`
- `doCheck = false` — integration tests need a real jj repo + git (sandbox-incompatible)
- Wraps binary with `jujutsu` and `gh` in PATH
- Installed via `modules/shell/jj/default.nix` as `pkgs.my.jut`

## Building & Testing

```bash
nix build .#jut              # Nix build
cd packages/jut && cargo build  # Dev build
cargo test                   # Integration tests (needs jj + git in PATH)
```

## Related Files

- `modules/shell/jj/default.nix` — installs jut alongside jj
- `config/jj/config.toml` — jj config (jut reads jj's config)
