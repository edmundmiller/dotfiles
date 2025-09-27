# PR Workflow Cheat Sheet

## Tool Selection

| Task | Tool | Commands |
|------|------|----------|
| 📊 **Daily PR triage** | `gh dash` | `gh dash` |
| 📝 **Review + comments** | `Octo.nvim` | `<leader>gi` → `:Octo review start` |
| 🔧 **Deep code analysis** | `diffview.nvim` | `gh pr checkout <n>` → `:DiffviewOpen main...HEAD` |
| 🔥 **Merge conflicts** | `diffview.nvim` | `:DiffviewOpen` → `<leader>co/ct/cb` |

## Quick Decision Tree

```
New PR? 
├── Multiple PRs to check? → gh dash
├── Need to comment? → Octo.nvim  
├── Complex changes? → diffview.nvim
└── Conflicts? → diffview.nvim
```

## Essential Commands

### gh dash
```bash
gh dash                    # Open dashboard
```

### Octo.nvim
```vim
<leader>gi                 # List issues/PRs
:Octo pr diff <number>     # Quick diff view
:Octo review start         # Start review with comments
```

### diffview.nvim
```bash
gh pr checkout <number>    # Checkout PR first
```
```vim
:DiffviewOpen main...HEAD  # Compare against main
:DiffviewFileHistory       # File history view
<leader>gC                 # Close diffview
```

**Conflict resolution:**
- `<leader>co` - Choose ours
- `<leader>ct` - Choose theirs  
- `<leader>cb` - Choose base
- `[x` / `]x` - Navigate conflicts

## Typical Workflows

1. **Morning routine**: `gh dash` → filter → pick tool for each PR
2. **Quick review**: `Octo.nvim` → comment → approve
3. **Complex review**: `gh pr checkout` → `diffview` → `Octo` for comments