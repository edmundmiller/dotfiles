---
purpose: Route changes to the Claude CLI Nix module.
applies_to: Claude package, startup instructions, modes, settings, plugins, or WakaTime wiring.
entrypoint: Edit modules/agents/claude/default.nix and its config sources.
verification: Rebuild and run the affected Claude smoke check.
update_when: Claude module ownership, paths, or runtime behavior changes.
---

# Claude CLI Module - Agent Guide

## Purpose

Minimal Nix module for Claude Code. It installs the shared thin core and modes
while preserving a small amount of Claude-specific runtime config.

## Key paths

- `modules/agents/claude/default.nix` - module definition
- `config/claude/settings.json` - Claude-specific settings template
- `config/agents/core.md` - source for `~/.claude/CLAUDE.md`
- `config/agents/modes/` - source for `~/.claude/agents/`
- `skills/catalog/test-quality/`, `skills/catalog/github-cli-media/`, and the
  selected `lore` source in `skills/flake.nix` - canonical targets of Claude's
  shared skill links
- `config/claude/plugins/` - repo-local Claude plugin sources

## Facts

- Enable with `modules.agents.claude.enable = true`
- Shared skills live in `~/.agents/skills`. Claude receives only
  `~/.claude/skills/{test-quality,github-cli-media,lore}`, linked to those
  canonical copies; other Claude skill copies are removed because OMP scans
  both directories.
- `~/.claude/settings.json` is bootstrapped as a writable local file, not a Home Manager symlink, so runtime integrations such as Herdr can mutate Claude hooks.
- Plugins are user-installed; this repo only keeps source trees and settings
- WakaTime config is Darwin-only and depends on `wakatime-api-key`
