# OpenCode Instructions

## Environment

- Nix-based dotfiles repo using **JJ** for version control (not git directly)
- Primary hosts: Seqeratop (work Mac), MacTraitor-Pro (personal), NUC (NixOS server)
- Shell is **non-interactive** (no TTY/PTY) - see `reference/shell-strategy.md` for command patterns

## Core Conventions

- Use `hey` command for all nix-darwin operations (`hey rebuild`, `hey update`, `hey nuc`, etc.)
- **JJ workflow**: describe -> new -> implement -> squash (see `/jj-status`, `@squash`)
- **Always overwrite source files** - never create `_v2`, `_enhanced`, or `_fixed` versions
- Don't make PRs in this repo - work directly on main bookmark
- After `hey rebuild`, restart terminal to pick up new environment

## Tool Guidelines

| Tool | Use When |
|------|----------|
| **Beads (bd)** | Multi-session work, dependencies, survives compaction |
| **TodoWrite** | Single-session execution tracking only |
| **Read/Write/Edit** | File operations (prefer over bash sed/cat/echo) |
| **JJ tools** | All version control (`/jj-status`, `@squash`, `@split`) |

## JJ Non-Interactive Commands

JJ commands that open editors will hang. Always use:
```bash
jj describe -m "message"           # Not: jj describe
jj squash -m "message"             # Not: jj squash  
JJ_EDITOR="echo 'msg'" jj split    # For interactive commands
```

## Skill Locations

- **Project skills**: `.claude/skills/<name>/SKILL.md` or `.opencode/skill/<name>/SKILL.md`
- **Global skills**: `~/.config/opencode/skills/<name>/SKILL.md`

## Critical Rules

- **Beads merge conflicts**: Use `jj resolve --tool=beads-merge` for `.beads/` files
- **Nix flakes**: Read from git index - run `jj git export` if changes aren't visible to nix
- **Plugins**: Manually managed in `~/.config/opencode/plugin/` (not nix-controlled)

## Reference Documentation

Detailed guides available in `reference/` directory - consult when needed:
- `shell-strategy.md` - Non-interactive command patterns and environment variables
