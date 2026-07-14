---
purpose: Route changes to the Claude CLI Nix module.
applies_to: Claude package, rules, modes, settings, plugins, or WakaTime wiring.
entrypoint: Edit modules/agents/claude/default.nix and its config sources.
verification: Rebuild and run the affected Claude smoke check.
update_when: Claude module ownership, paths, or runtime behavior changes.
---

# Claude CLI Module - Agent Guide

## Purpose

Minimal Nix module for Claude Code. It keeps Claude pointed at the shared rules and modes while preserving a small amount of Claude-specific runtime config.

## Key paths

- `modules/agents/claude/default.nix` - module definition
- `config/claude/settings.json` - Claude-specific settings template
- `config/agents/rules/` - source for `~/.claude/CLAUDE.md`
- `config/agents/modes/` - source for `~/.claude/agents/`
- `config/claude/plugins/` - repo-local Claude plugin sources

## Facts

- Enable with `modules.agents.claude.enable = true`
- Shared skills live in `~/.agents/skills`; `~/.claude/skills` is intentionally removed because OMP would discover duplicate copies.
- `~/.claude/settings.json` is bootstrapped as a writable local file, not a Home Manager symlink, so runtime integrations such as Herdr can mutate Claude hooks.
- Plugins are user-installed; this repo only keeps source trees and settings
- WakaTime config is Darwin-only and depends on `wakatime-api-key`
