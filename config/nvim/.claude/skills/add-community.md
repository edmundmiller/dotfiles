---
skill_name: nvim:add-community
description: Add AstroCommunity plugin packs to the configuration
allowed-tools:
  - Read
  - Edit
  - WebFetch
  - Grep
---

# Add AstroCommunity Plugin

Use this skill when the user wants to add a plugin pack from AstroCommunity to their AstroNvim configuration.

## Context

This configuration uses AstroCommunity, a repository of pre-configured plugin packs organized into categories. Community packs are imported in `lua/community.lua` and can be customized in `lua/plugins/user.lua`.

See `.claude/CONTEXT.md` for:

- Community categories and available packs
- Import patterns
- Customization examples

## Your Task

When the user requests adding a community plugin:

1. **Understand the request**
   - Identify which plugin or pack they want
   - If unclear, search AstroCommunity categories in CONTEXT.md
   - If not found in CONTEXT, fetch from https://astronvim.github.io/astrocommunity/

2. **Check current configuration**
   - Read `lua/community.lua` to see existing imports
   - Check if the pack or similar functionality already exists

3. **Add the import**
   - Edit `lua/community.lua` to add the import
   - Organize by category (maintain existing structure)
   - Format: `{ import = "astrocommunity.category.pack-name" }`
   - Add comment indicating category if helpful

4. **Document customization options**
   - If the pack has common customization options, mention them
   - Point to `lua/plugins/user.lua` for customization pattern
   - Explain if any external tools need installation

5. **Verify compatibility**
   - Check if it conflicts with existing plugins
   - Warn about potential keybinding conflicts

## Example Workflow

**User request**: "Add the octo.nvim community pack for GitHub integration"

**Your response**:

1. Read `lua/community.lua` to check for existing Git plugins
2. Add import: `{ import = "astrocommunity.git.octo-nvim" }`
3. Explain what octo.nvim provides
4. Note: "To customize octo.nvim settings, add configuration to `lua/plugins/user.lua`"
5. Mention: "Requires `gh` CLI tool for authentication"

## Important Notes

- **Read first**: Always read `lua/community.lua` before editing
- **Preserve structure**: Maintain the existing organization and formatting
- **Comment wisely**: Add category comments if they help organization
- **Check duplicates**: Don't add packs that provide overlapping functionality
- **External deps**: Mention if the pack requires external tools (gh, ripgrep, etc.)

## Related Patterns

- See `/nvim:community` slash command for quick import
- See CONTEXT.md for full list of major categories
- Use `nvim:plugin-docs` skill to research unfamiliar packs
