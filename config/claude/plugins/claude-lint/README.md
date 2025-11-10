# claude-lint Plugin

Real-time validation of Claude Code plugin files using [claudelint](https://github.com/stbenjam/claudelint).

## Overview

This plugin automatically validates Claude Code plugin files during development, providing immediate feedback when you edit plugin configurations, commands, skills, or hooks.

## Features

- **Real-time validation**: Runs after Write/Edit operations on plugin files
- **Comprehensive checks**: Validates plugin.json, commands, skills, and hooks
- **Non-blocking**: Shows warnings but doesn't prevent file operations
- **Multi-layer protection**: Works alongside CI, pre-commit hooks, and flake checks

## What Gets Validated

The plugin monitors changes to:

- `config/claude/plugins/*/plugin.json` - Plugin metadata and configuration
- `config/claude/plugins/*/commands/*.md` - Slash command definitions
- `config/claude/plugins/*/skills/*/*.md` - Skill definitions
- `config/claude/plugins/*/hooks/*.(py|mjs|js|ts)` - Hook implementations
- `config/claude/skills/*.md` - Standalone skill files

## How It Works

1. Hook triggers on Write/Edit tool calls for plugin files
2. Extracts modified file paths from the tool batch
3. Identifies affected plugin directories
4. Runs `uvx claudelint` on each plugin directory
5. Displays validation results inline

## Validation Results

When you save plugin files, you'll see validation feedback:

```
## Plugin Validation Results

✅ **config/claude/plugins/jj**

❌ **config/claude/plugins/my-plugin**
```

ERROR: plugin.json missing required field: version
ERROR: hooks/invalid.py is not executable

```

⚠️ Some plugin files failed validation. Please review the errors above.
```

## Configuration

Validation rules are configured in `.claudelint.toml` at the repository root.

## Validation Layers

This plugin is part of a multi-layer validation system:

1. **Real-time (this plugin)**: Immediate feedback during editing
2. **Pre-commit hook**: Validates before commit (`.git/hooks/pre-commit`)
3. **CI/CD**: GitHub Actions validation on push/PR
4. **Flake checks**: `hey check` or `nix flake check`

## Dependencies

- [claudelint](https://github.com/stbenjam/claudelint) (installed via uvx)
- [uv](https://astral.sh/uv) (for running claudelint)

## Disabling

To temporarily disable validation, you can:

1. Remove or rename the plugin directory
2. Disable the plugin in Claude Code settings
3. Modify the hook matcher in `plugin.json`

## Technical Details

- **Hook Type**: `ToolCallBatch:Callback`
- **Triggers**: Write, Edit operations on plugin files
- **Implementation**: Python UV script (`hooks/validate-on-save.py`)
- **Timeout**: 30 seconds per plugin directory
- **Mode**: Non-blocking (warnings only)
