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
