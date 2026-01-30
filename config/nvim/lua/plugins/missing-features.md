# Missing Features from Old Neovim Configuration

This document tracks features from the old Neovim configuration that haven't been migrated yet to the new AstroNvim v5 setup.

## ✅ Successfully Migrated

### From AstroCommunity

- **Catppuccin** - Configured with latte (light) theme
- **Neogit** - Git integration
- **Git-blame.nvim** - Git blame information
- **Diffview.nvim** - Better diff viewing
- **Obsidian.nvim** - Note-taking with Obsidian
- **Blink.cmp** - Modern completion
- **Mini.comment** - Enhanced commenting
- **Neotest** - Testing framework
- **Toggleterm-manager** - Terminal management
- **Python pack** - Complete Python development environment
- **Julia pack** - Julia language support
- **Todo-comments.nvim** - TODO/FIXME/HACK comment tracking
- **Flash.nvim** - Enhanced navigation and motions
- **Project.nvim** - Smart project detection
- **Refactoring.nvim** - Language-aware refactoring
- **Yanky.nvim** - Enhanced yank/paste with history
- **Grug-far.nvim** - Find and replace across files
- **Render-markdown.nvim** - Beautiful markdown rendering
- **Zen-mode.nvim** - Distraction-free coding
- **Inc-rename.nvim** - Preview rename operations

### Custom Plugins Added

- **Claudecode.nvim** - Official Claude Code integration (`lua/plugins/claudecode.lua`)
- **Toggleterm.nvim** - Persistent terminal management (`lua/plugins/terminal-repl.lua`)
- **Iron.nvim** - REPL integration for Python/R/Julia/Nextflow (`lua/plugins/terminal-repl.lua`)
- **Git-worktree.nvim** - Git worktree management (`lua/plugins/git-worktree.lua`)

## 🚧 Not Yet Migrated

### AI/LLM Tools

- **CodeCompanion.nvim** - Alternative AI companion
  - Status: ✅ Available in AstroCommunity (`astrocommunity.editing-support.codecompanion-nvim`)
  - Currently using Claudecode.nvim instead, but available as alternative

### Org-mode Ecosystem

- **nvim-orgmode/orgmode** - Full org-mode implementation
  - Reason: Using Neorg as alternative (available in AstroCommunity)
  - Features missing from Neorg:
    - GTD-style TODO keywords (TODO/NEXT/WAITING/DONE/CANCELLED)
    - Org-agenda views
    - Org-capture templates
    - Logbook drawer functionality

- **org-roam.nvim** - Zettelkasten for org-mode
  - Reason: Would require full org-mode; consider using Obsidian or Neorg equivalents

- **vim-table-mode** - Table support for org/markdown
  - Status: May add if needed for markdown tables

### Testing

- **Custom nf-test adapter** - Nextflow test integration
  - Located in old config: `lua/neotest-nftest/`
  - Status: Needs to be ported as a custom neotest adapter
  - Priority: Medium (important for bioinformatics work)

### Doom Emacs Features

- **doom-notifications.lua** - Doom-style notifications
- **doom-enhancements.lua** - Various Doom Emacs enhancements
- **doom-motion.lua** - Doom-style motion commands
  - Note: Flash.nvim provides similar enhanced motion capabilities
- **doom-text-objects.lua** - Custom text objects
- **which-key-doom.lua** - Doom-style which-key configuration
  - Status: Consider if current keybindings are insufficient

### Session Management

- **session-management.lua** - Custom session management
  - Status: Check if AstroNvim's built-in session management is sufficient

### Database

- **database.lua** - Database integration
  - Status: Add if database work becomes necessary

### Language-specific

- **vale.lua** - Prose linting with Vale
  - Status: Add if writing documentation frequently

### UI/UX

- **snacks-zen.lua** - Zen mode from Snacks.nvim
  - Status: ✅ Zen-mode.nvim added from AstroCommunity as alternative
- **snacks-picker.lua** - Enhanced picker
- **snacks-explorer.lua** - File explorer
  - Note: AstroNvim uses neo-tree by default

### Other Themes

- **melange.lua** - Melange colorscheme
- **onedark.lua** - OneDark colorscheme
  - Status: Available in AstroCommunity if needed

## 📝 Implementation Notes

### To Add a Missing Feature

1. Check if it's available in AstroCommunity first:

   ```lua
   -- In lua/community.lua
   { import = "astrocommunity.category.plugin-name" }
   ```

2. If not in AstroCommunity, create a custom plugin file:

   ```lua
   -- In lua/plugins/feature-name.lua
   return {
     "author/plugin-name",
     -- configuration
   }
   ```

3. For complex features (like nf-test adapter), may need to:
   - Port the old adapter code
   - Create proper plugin structure
   - Integrate with existing neotest setup

### Priority Order for Future Additions

1. **High Priority**
   - Custom nf-test adapter (essential for Nextflow development)

2. **Medium Priority**
   - Org-mode features not covered by Neorg
   - Vale for prose linting
   - Session management enhancements

3. **Low Priority**
   - Additional themes
   - Doom Emacs specific enhancements
   - Database integration

## 🔄 Migration Status

- **Total features identified**: ~45
- **Successfully migrated**: ~33 (20 original + 13 new AstroCommunity additions)
- **Available but not needed**: ~5
- **To be migrated**: ~7 (mainly custom adapters and Doom-specific features)

### Recent Additions from AstroCommunity:

- Python and Julia language packs for complete development environment
- Enhanced navigation with Flash.nvim
- Project management with Project.nvim
- Code quality tools: refactoring, TODO comments, find/replace
- Productivity features: yanky, zen-mode, inc-rename
- Documentation: render-markdown for better markdown experience

Last updated: 2025-10-06
