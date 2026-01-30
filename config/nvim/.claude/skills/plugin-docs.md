---
skill_name: nvim:plugin-docs
description: Research and fetch plugin documentation from web sources
allowed-tools:
  - WebFetch
  - WebSearch
  - Read
---

# Plugin Documentation Research

Use this skill when you need to research unfamiliar Neovim plugins, understand their configuration options, or find specific features.

## Context

This is a helper skill for the other nvim skills. Use it when:

- User mentions a plugin you're not familiar with
- Need to understand configuration options
- Researching AstroCommunity packs
- Finding keybinding conventions for a plugin

See `.claude/CONTEXT.md` for local patterns, but this skill fetches live documentation.

## Your Task

When you need to research a plugin:

1. **Identify the plugin**
   - Get the full repository name (author/plugin-name)
   - Determine if it's a community pack or standalone plugin
   - Check if it's already configured locally first

2. **Fetch documentation**
   - **GitHub README**: Primary source for most plugins
   - **AstroCommunity page**: For community packs
   - **Plugin help docs**: If available online
   - **LSP server docs**: For language server configuration

3. **Extract key information**
   - What the plugin does (purpose and features)
   - Installation/setup requirements
   - Configuration options structure
   - Default and recommended keybindings
   - External dependencies (tools, languages)
   - Conflicts with other plugins

4. **Summarize findings**
   - Provide concise summary of the plugin
   - Note key configuration options
   - Mention integration points (Telescope, which-key, etc.)
   - Identify potential conflicts with existing setup

## Research Workflow

### For Standalone Plugins

1. **Fetch GitHub README**

   ```
   WebFetch: https://github.com/author/plugin-name
   Prompt: "Extract the plugin's purpose, key features, installation requirements,
           configuration options, default keybindings, and external dependencies."
   ```

2. **Check for help docs**
   - Look for `/doc/` directory in README
   - Check if Neovim help is available (`:help plugin-name`)

3. **Summarize for configuration**
   - How it fits the existing setup
   - Suggested keybinding prefix
   - Required dependencies

### For AstroCommunity Packs

1. **Check CONTEXT.md first**
   - See if pack is listed in major categories
   - Check existing `lua/community.lua` for similar packs

2. **Fetch AstroCommunity page**

   ```
   WebFetch: https://astronvim.github.io/astrocommunity/
   Prompt: "Find information about the [pack-name] pack in [category] category.
           Extract its purpose, included plugins, and configuration notes."
   ```

3. **Research underlying plugins**
   - If pack includes unfamiliar plugins, fetch their docs
   - Understand how plugins in pack work together

### For LSP Servers

1. **Fetch nvim-lspconfig docs**

   ```
   WebFetch: https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
   Prompt: "Find configuration documentation for [server-name] LSP server.
           Extract server settings structure, required dependencies, and default configuration."
   ```

2. **Check language server repository**
   - Often has more detailed settings documentation
   - Shows all available configuration options

## Example Workflows

### Research Unfamiliar Plugin

**Scenario**: Need to understand `telescope-frecency.nvim`

**Your actions**:

1. Fetch README:
   ```
   WebFetch: https://github.com/nvim-telescope/telescope-frecency.nvim
   Prompt: "What is telescope-frecency? Extract its purpose, how it works,
           installation requirements, configuration options, and keybindings."
   ```
2. Summarize: "Frecency is a Telescope extension that sorts files by frequency + recency.
   Requires sqlite.lua dependency. Adds `:Telescope frecency` command.
   Common binding: `<leader>fr`."
3. Note integration: "Works with Telescope, fits under `<leader>f` prefix with other file operations."

### Research AstroCommunity Pack

**Scenario**: User wants to add "pack.python" but you need to know what's included

**Your actions**:

1. Check CONTEXT.md for Python pack details
2. If needed, fetch AstroCommunity docs:
   ```
   WebFetch: https://astronvim.github.io/astrocommunity/
   Prompt: "Find the Python language pack. What plugins and LSP servers does it include?"
   ```
3. Research any unfamiliar components
4. Summarize: "Python pack includes pyright LSP, debugging support, virtual environment detection,
   and testing integration with neotest."

### Research LSP Configuration

**Scenario**: Need to configure rust-analyzer but unfamiliar with its settings

**Your actions**:

1. Fetch nvim-lspconfig docs for rust_analyzer
2. Check rust-analyzer manual if needed:
   ```
   WebFetch: https://rust-analyzer.github.io/manual.html
   Prompt: "Extract common configuration settings for rust-analyzer, especially for
           checkOnSave, cargo features, and clippy integration."
   ```
3. Summarize key settings structure and options

## Common Documentation Sources

### Plugin Documentation

- **GitHub README**: `https://github.com/[author]/[plugin]`
- **Plugin docs**: Often in `/doc/` directory
- **Example configs**: Look for `/examples/` or wiki

### AstroNvim Resources

- **AstroCommunity**: `https://astronvim.github.io/astrocommunity/`
- **AstroNvim Docs**: `https://docs.astronvim.com/`
- **Recipes**: Configuration examples for common setups

### LSP Resources

- **nvim-lspconfig**: Server configurations and settings
- **Language server docs**: Official documentation for each server
- **Mason registry**: Tool installation information

### General Neovim

- **Awesome Neovim**: Plugin discovery
- **Neovim docs**: `:help` and online documentation

## Important Notes

- **Check local first**: Read existing config before fetching external docs
- **Focus on essentials**: Extract only relevant configuration info
- **Note dependencies**: Always mention external requirements
- **Integration points**: Identify how plugin fits existing setup
- **Be concise**: Summarize findings, don't dump entire README

## Related Patterns

- This skill supports all other nvim skills
- Use when adding plugins (nvim:add-plugin)
- Use when researching community packs (nvim:add-community)
- Use when configuring LSP (nvim:lsp-config)
- Always check CONTEXT.md patterns first
