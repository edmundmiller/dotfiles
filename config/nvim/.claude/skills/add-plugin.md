---
skill_name: nvim:add-plugin
description: Create custom plugin configuration files for AstroNvim
allowed-tools:
  - Read
  - Write
  - WebFetch
  - Grep
  - Glob
---

# Add Custom Plugin

Use this skill when the user wants to add a custom plugin configuration (not from AstroCommunity) to their AstroNvim setup.

## Context

Custom plugins are added as individual files in `lua/plugins/`. Each file returns a Lazy.nvim plugin specification with configuration, dependencies, keybindings, and lazy-loading options.

See `.claude/CONTEXT.md` for:

- Plugin file templates (standard, extended, local dev)
- Keybinding organization and prefixes
- Common patterns and best practices

## Your Task

When the user requests adding a plugin:

1. **Understand the plugin**
   - Identify the plugin repository (author/plugin-name)
   - Research the plugin if needed (use WebFetch for GitHub README)
   - Understand what it does and why the user wants it

2. **Check for conflicts**
   - Search existing `lua/plugins/` for similar functionality
   - Check `lua/community.lua` for overlapping community packs
   - Verify keybinding prefix availability in `lua/plugins/astrocore.lua`

3. **Choose appropriate template**
   - **Standard**: Simple plugin with basic options
   - **Extended**: Complex plugin needing documentation
   - **Local dev**: Plugin under development (`dev = true`)
   - **Local directory**: Custom implementation in lua/

4. **Create the plugin file**
   - Filename: `lua/plugins/plugin-name.lua` (kebab-case)
   - Use appropriate template from CONTEXT.md
   - Include documentation header for complex plugins
   - Configure lazy-loading (`cmd`, `keys`, `ft`, `event`)

5. **Configure keybindings**
   - Assign appropriate `<leader>X` prefix (see CONTEXT.md)
   - Add keybindings in plugin's `keys = {}` table
   - Include which-key group registration if needed
   - Always add `desc` for discoverability

6. **Document and explain**
   - Explain what the plugin does
   - Mention required external tools if any
   - Note how it complements existing plugins
   - Suggest next steps (reload config, test commands)

## Example Workflow

**User request**: "Add vim-fugitive for advanced Git operations"

**Your response**:

1. Check existing Git plugins (neogit, fugit2, etc. in config)
2. Note: "Fugitive complements your existing JJ workflow for Git operations"
3. Create `lua/plugins/vim-fugitive.lua`:

   ```lua
   -- Vim Fugitive - Git integration
   -- Complements: JJ workflow, neogit for pure Git operations

   ---@type LazySpec
   return {
     "tpope/vim-fugitive",
     cmd = { "Git", "Gwrite", "Gread", "Gdiffsplit" },
     keys = {
       { "<Leader>gG", "<cmd>Git<cr>", desc = "Fugitive status" },
       { "<Leader>gb", "<cmd>Git blame<cr>", desc = "Git blame" },
     },
     dependencies = {
       "AstroNvim/astrocore",
       opts = {
         mappings = {
           n = {
             ["<Leader>gG"] = { "<cmd>Git<cr>", desc = "Fugitive status" },
           },
         },
       },
     },
   }
   ```

4. Explain: "Added under `<leader>g` (Git prefix). Lazy-loads on commands or keybindings."
5. Note: "Reload with `:Lazy reload vim-fugitive` or restart Neovim"

## Important Patterns

### Lazy Loading Strategies

Choose based on usage:

- `cmd = { "CommandName" }` - Load on command execution
- `keys = { ... }` - Load on keybinding press
- `ft = { "filetype" }` - Load on filetype detection
- `event = "VeryLazy"` - Load after startup (last resort)

### Keybinding Organization

Follow the Doom Emacs-style prefixes (see CONTEXT.md):

- `<leader>f` - Files
- `<leader>s` - Search
- `<leader>b` - Buffers
- `<leader>g` - Git
- `<leader>c` - Code
- `<leader>t` - Toggle
- `,` (local leader) - Language-specific

### Which-key Integration

Register key groups for multi-key prefixes:

```lua
dependencies = {
  "AstroNvim/astrocore",
  opts = {
    mappings = {
      n = {
        ["<Leader>x"] = { name = "Category Name" },
      },
    },
  },
},
```

### Documentation Headers

For complex plugins, add header:

```lua
-- Plugin Name
-- https://github.com/author/plugin
--
-- Description of purpose and functionality
--
-- Key features:
-- - Feature 1
-- - Feature 2
--
-- Complements: other-plugin
```

## Important Notes

- **Read existing config**: Check current plugins to avoid duplicates
- **Follow conventions**: Use existing keybinding prefixes
- **Lazy load**: Always specify `cmd`, `keys`, `ft`, or `event`
- **Document well**: Add headers for complex plugins
- **Test locally**: Suggest `:Lazy reload plugin-name` for testing

## Related Patterns

- See `/nvim:plugin` slash command for quick plugin creation
- Use `nvim:keybindings` skill for complex keybinding setup
- Use `nvim:plugin-docs` skill to research unfamiliar plugins
- Check CONTEXT.md for comprehensive templates
