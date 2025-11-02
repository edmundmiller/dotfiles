Add an AstroCommunity plugin pack to the configuration.

If the user provides a pack name or category, add the import to `lua/community.lua`.

## Your Task

1. **Parse the pack reference** from command arguments
   - Accept formats: "pack-name", "category.pack-name", or just category to list options
   - Examples: "octo-nvim", "git.octo-nvim", "pack.python"

2. **Invoke the nvim:add-community skill** to handle the implementation
   - The skill will verify the pack exists
   - Check for conflicts with existing config
   - Add the import to community.lua
   - Document any customization options

3. **Provide guidance**
   - Explain what the pack includes
   - Note any external dependencies
   - Point to `lua/plugins/user.lua` for customization
   - Suggest reload/restart

## Examples

**Command**: `/nvim:community octo-nvim`
**Action**: Add `{ import = "astrocommunity.git.octo-nvim" }` to community.lua

**Command**: `/nvim:community pack.python`
**Action**: Add Python language pack with LSP, testing, and tooling

**Command**: `/nvim:community git`
**Action**: List available Git-related community packs from CONTEXT.md

## Notes

- Check .claude/CONTEXT.md for category list
- Verify pack isn't already imported
- Suggest customization if commonly needed
- Mention complementary packs (e.g., git.diffview with git.neogit)
