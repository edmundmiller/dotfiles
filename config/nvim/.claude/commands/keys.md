Add or manage keybindings in the AstroNvim configuration.

If the user provides a keybinding specification, add it to the appropriate location following Doom Emacs-style conventions.

## Your Task

1. **Parse the keybinding request**
   - Key combination (e.g., `<leader>fa`, `,r`, `<C-s>`)
   - Action/command to bind
   - Category/prefix if creating new group
   - Mode (normal, visual, insert) - default to normal

2. **Invoke the nvim:keybindings skill** to handle implementation
   - The skill will check existing bindings
   - Determine appropriate location (astrocore.lua vs plugin file)
   - Add keybinding with proper desc for which-key
   - Register group if creating new prefix

3. **Explain the addition**
   - What prefix category it's under
   - How to discover it with which-key
   - How to test the keybinding

## Examples

**Command**: `/nvim:keys <leader>fp for project files`
**Action**: Add to Files prefix (`<leader>f`) in astrocore.lua with Telescope integration

**Command**: `/nvim:keys <leader>d for database operations`
**Action**: Create new Database prefix group with initial keybindings

**Command**: `/nvim:keys ,r to run current file`
**Action**: Add local-leader keybinding for quick file execution

## Notes

- Check .claude/CONTEXT.md for prefix conventions
- Verify keybinding isn't already taken
- Always include `desc` field for which-key
- Follow mnemonic prefix system (Files→f, Git→g, Code→c, etc.)
- Suggest appropriate mode (normal by default)
