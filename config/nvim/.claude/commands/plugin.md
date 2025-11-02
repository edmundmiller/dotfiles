Add a custom plugin configuration to AstroNvim.

If the user provides a plugin name or repository (author/plugin-name), create a new plugin configuration file for it.

## Your Task

1. **Parse the plugin name** from the command arguments or ask if not provided
   - Accept formats: "plugin-name", "author/plugin-name", or full GitHub URL

2. **Invoke the nvim:add-plugin skill** to handle the implementation
   - The skill will research the plugin if needed
   - Create the appropriate plugin file
   - Configure keybindings and lazy-loading
   - Document the plugin

3. **Provide clear next steps**
   - How to reload the configuration
   - How to test the plugin
   - Mention any required external dependencies

## Examples

**Command**: `/nvim:plugin telescope-frecency.nvim`
**Action**: Create `lua/plugins/telescope-frecency.lua` with proper Telescope integration

**Command**: `/nvim:plugin folke/trouble.nvim`
**Action**: Create `lua/plugins/trouble.lua` with diagnostics integration under `<leader>x` prefix

## Notes

- Check for existing plugin files before creating
- Use nvim:plugin-docs skill if plugin is unfamiliar
- Follow patterns from .claude/CONTEXT.md
- Suggest appropriate keybinding prefix based on plugin category
