---
skill_name: nvim:keybindings
description: Manage keybindings in AstroNvim configuration with which-key integration
allowed-tools:
  - Read
  - Edit
  - Grep
---

# Manage Keybindings

Use this skill when the user wants to add, modify, or organize keybindings in their AstroNvim configuration.

## Context

Keybindings in this configuration follow a Doom Emacs-style approach with mnemonic prefixes. The primary keybinding hub is `lua/plugins/astrocore.lua`, though plugin-specific keybindings can live in individual plugin files.

See `.claude/CONTEXT.md` for:

- Leader key prefix organization
- Keybinding templates and patterns
- Which-key integration examples

## Your Task

When the user requests keybinding changes:

1. **Understand the request**
   - What action needs a keybinding?
   - Is it global or plugin-specific?
   - What prefix category does it belong to?

2. **Check existing bindings**
   - Read `lua/plugins/astrocore.lua` to see current mappings
   - Check the specific prefix area (e.g., `<leader>g` for Git)
   - Verify the keybinding isn't already taken
   - Search plugin files if it might be plugin-specific

3. **Choose the right location**
   - **astrocore.lua**: Global keybindings, cross-plugin actions
   - **Plugin file**: Plugin-specific keybindings in `keys = {}`
   - **Local leader (`,`)**: Language/filetype-specific actions

4. **Add the keybinding**
   - Follow the existing pattern and indentation
   - Use appropriate prefix from the organization scheme
   - Include `desc` field for which-key discoverability
   - Register which-key group for new prefixes

5. **Test and document**
   - Suggest testing with `:verbose map <key>` to check conflicts
   - Explain what the keybinding does
   - Note which-key will show it in the help menu

## Keybinding Patterns

### Global Keybinding (astrocore.lua)

```lua
-- In lua/plugins/astrocore.lua under mappings = { n = { ... } }
["<Leader>fa"] = { "<cmd>Telescope find_files<cr>", desc = "Find files" },
["<Leader>fb"] = {
  function()
    require("telescope.builtin").buffers()
  end,
  desc = "Find buffers",
},
```

### Which-key Group Registration

```lua
-- Register group name for prefix
["<Leader>x"] = { name = "Category Name" },
["<Leader>xa"] = { "<cmd>Action<cr>", desc = "Action description" },
["<Leader>xb"] = { "<cmd>Another<cr>", desc = "Another action" },
```

### Plugin-Specific Keybinding

```lua
-- In lua/plugins/plugin-name.lua
keys = {
  { "<Leader>xa", "<cmd>PluginAction<cr>", desc = "Action description" },
  {
    "<Leader>xb",
    function()
      require("plugin").action()
    end,
    desc = "Lua function action",
  },
},
```

### Mode-Specific Bindings

```lua
-- In astrocore.lua
mappings = {
  n = {  -- Normal mode
    ["<Leader>fa"] = { "<cmd>Action<cr>", desc = "Normal mode action" },
  },
  v = {  -- Visual mode
    ["<Leader>fa"] = { "<cmd>Action<cr>", desc = "Visual mode action" },
  },
  i = {  -- Insert mode
    ["<C-s>"] = { "<cmd>w<cr>", desc = "Save file" },
  },
},
```

## Leader Prefix Reference

| Prefix      | Category    | Use For                           |
| ----------- | ----------- | --------------------------------- |
| `<leader>f` | Files       | File operations, finding, opening |
| `<leader>s` | Search      | Searching buffers, projects, help |
| `<leader>b` | Buffers     | Buffer management                 |
| `<leader>w` | Windows     | Window/split operations           |
| `<leader>g` | Git/VCS     | Git and JJ operations             |
| `<leader>c` | Code        | LSP actions, refactoring          |
| `<leader>t` | Toggle      | Toggle UI elements, settings      |
| `<leader>n` | Notes/Tools | Custom tools, notes               |
| `<leader>h` | Help        | Help and documentation            |
| `<leader>q` | Quit        | Exit operations                   |
| `,` (local) | Language    | LSP, testing, language-specific   |

## Example Workflows

### Add Git keybinding

**User request**: "Add a keybinding for git push under the Git prefix"

**Your response**:

1. Read `lua/plugins/astrocore.lua` under `["<Leader>g"]` section
2. Find available key (e.g., `<Leader>gp` is available)
3. Add:
   ```lua
   ["<Leader>gp"] = { "<cmd>!git push<cr>", desc = "Git push" },
   ```
4. Explain: "Added `<leader>gp` for git push under the Git prefix. Use which-key (`<leader>` then wait) to see it."

### Add new prefix category

**User request**: "Add keybindings for database operations under `<leader>d`"

**Your response**:

1. Check that `<leader>d` is not already used
2. Add group and actions:
   ```lua
   ["<Leader>d"] = { name = "Database" },
   ["<Leader>dc"] = { "<cmd>DBConnect<cr>", desc = "Connect to database" },
   ["<Leader>dq"] = { "<cmd>DBQuery<cr>", desc = "Run query" },
   ```
3. Explain the new prefix and how it fits the convention

### Add plugin-specific keybinding

**User request**: "Add keybinding for opening Neogit commit window"

**Your response**:

1. Check `lua/plugins/neogit.lua` (or relevant plugin file)
2. Add to plugin's `keys = {}` table:
   ```lua
   { "<Leader>gc", "<cmd>Neogit commit<cr>", desc = "Neogit commit" },
   ```
3. Alternative: Add to `astrocore.lua` if it's a global action
4. Explain the choice and why it's under `<leader>g`

## Important Notes

- **Read first**: Always check existing keybindings before adding
- **Mnemonic**: Use prefixes that make sense (Git → `g`, Files → `f`)
- **Descriptions**: Always include `desc` for which-key
- **Groups**: Register new prefixes with `name` field
- **Check conflicts**: Test with `:verbose map <key>` in Neovim
- **Follow conventions**: Use the established prefix system

## Advanced Patterns

### Conditional Keybindings

```lua
-- In astrocore.lua
{
  "<Leader>ca",
  function()
    if vim.lsp.buf.server_ready() then
      vim.lsp.buf.code_action()
    end
  end,
  desc = "Code action",
}
```

### Buffer-Local Keybindings

```lua
-- In astrocore.lua autocmds
autocmds = {
  python_bindings = {
    {
      event = "FileType",
      pattern = "python",
      callback = function()
        vim.keymap.set("n", ",r", "<cmd>!python %<cr>", { buffer = true, desc = "Run Python" })
      end,
    },
  },
},
```

## Related Patterns

- See `/nvim:keys` slash command for quick keybinding addition
- See CONTEXT.md for comprehensive prefix reference
- Check individual plugin files for plugin-specific patterns
