# Version Control

## Worktrunk (Git Worktrees)

### Bare Repository Layout

All new repos should use bare repository layout:

```bash
# Clone as bare repo
gcl https://github.com/user/myproject
cd myproject
wt switch -c main  # Create first worktree

# Structure:
# myproject/
# ├── .git/       # bare repository
# ├── main/       # main branch worktree
# └── feature/    # feature branch worktree
```

### Migrating Existing Repos to Bare Layout

```bash
# 1. Backup and note current branch
cd ~/code/myproject
git branch  # note current branch

# 2. Create bare repo structure
mkdir -p ~/code/myproject-new
git clone --bare . ~/code/myproject-new/.git
cd ~/code/myproject-new

# 3. Create worktrees for active branches
wt switch -c main
wt switch -c feature/active-work  # any in-progress branches

# 4. Copy uncommitted work (if any)
cp -r ~/code/myproject/.env ~/code/myproject-new/main/  # etc

# 5. Verify and clean up
cd ~/code/myproject-new/main
git log --oneline -5  # verify history
rm -rf ~/code/myproject  # remove old repo
mv ~/code/myproject-new ~/code/myproject
```

### Dotfiles Exception

The dotfiles repo uses sibling layout (`../dotfiles.branch`) via `.envrc` override. This is for historical compatibility with existing worktrees.

## git-hunks (Non-Interactive Hunk Staging)

For selective hunk staging without interactive prompts. Designed for AI agents.

### Commands

```bash
# List all hunks with stable IDs
git hunks list

# List staged hunks
git hunks list --staged

# Stage a specific hunk by ID
git hunks add <hunk-id>

# Unstage a specific hunk
git hunks add <hunk-id> --reverse
```

### Hunk ID Format

IDs are stable and deterministic: `file:@-old,len+new,len`

Example: `README.md:@-1,3+1,5` means:
- File: `README.md`
- Old: starts line 1, length 3
- New: starts line 1, length 5

### Workflow Example

```bash
# 1. Make changes to multiple files
echo "fix" >> auth.ts
echo "unrelated" >> readme.md

# 2. List available hunks
git hunks list
# auth.ts:@-10,2+10,3
# readme.md:@-1,1+1,2

# 3. Stage only the fix
git hunks add auth.ts:@-10,2+10,3

# 4. Commit the fix, leave unrelated changes unstaged
git commit -m "fix auth bug"
```

### When to Use

- Precise commits: stage only relevant changes
- AI workflows: programmatic staging without interactive prompts
- Separating concerns: split unrelated changes into multiple commits
