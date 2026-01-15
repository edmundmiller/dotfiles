#!/usr/bin/env zsh

g() { [[ $# = 0 ]] && git status --short . || git $*; }

alias ga='git add'
alias gap='git add --patch'
alias gb='git branch'
alias gbr='git browse'
alias gbl='git blame'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcf='git commit --fixup'
# gcl: Clone as bare repo for worktrunk workflow
# Usage: gcl <url> [name]
# Creates: name/.git (bare repo), ready for wt switch -c main
gcl() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: gcl <url> [directory]"
    echo "Creates a bare repository for use with worktrunk"
    return 1
  fi
  local url=$1
  local name=${2:-$(basename "$url" .git)}
  git clone --bare "$url" "${name}/.git" && \
    echo "Bare repo created. Next: cd $name && wt switch -c main"
}

# g2bare: convert existing repo to bare + worktrunk layout IN-PLACE
# Usage: g2bare
# Transforms current repo: .git (normal) → .git (bare) + worktree
# Requires clean working tree. Indiana Jones style - seamless swap.
g2bare() {
  local repo_root current_branch temp_dir worktree_path

  # 1. Pre-flight checks
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "✗ Not in a git repository"
    return 1
  }

  # Must be at repo root for in-place transform (resolve symlinks for comparison)
  local current_dir
  current_dir=$(cd -P . && pwd)
  repo_root=$(cd -P "$repo_root" && pwd)
  if [[ "$current_dir" != "$repo_root" ]]; then
    echo "✗ Must run from repository root: $repo_root"
    return 1
  fi

  # Check if already bare
  if [[ $(git rev-parse --is-bare-repository) == "true" ]]; then
    echo "✗ Already a bare repository"
    return 1
  fi

  # Require clean working tree
  if [[ -n $(git status --porcelain) ]]; then
    echo "✗ Uncommitted changes detected"
    echo "↳ Commit or stash changes first, then retry"
    return 1
  fi

  # Get current branch
  current_branch=$(git branch --show-current)
  if [[ -z "$current_branch" ]]; then
    current_branch="main"
  fi

  # Check wt is available
  if ! command -v wt >/dev/null 2>&1; then
    echo "✗ worktrunk (wt) not found"
    echo "↳ Install: brew install max-sixty/tap/worktrunk"
    return 1
  fi

  # 2. Create temp bare clone
  temp_dir=$(mktemp -d /tmp/g2bare.XXXXXX)
  echo "Creating bare clone..."
  if ! git clone --bare . "$temp_dir/.git" 2>/dev/null; then
    echo "✗ Failed to create bare clone"
    rm -rf "$temp_dir"
    return 1
  fi

  # 3. The Swap (Indiana Jones moment)
  echo "Transforming in-place..."

  # Backup original .git
  if ! mv .git .git.old; then
    echo "✗ Failed to backup .git"
    rm -rf "$temp_dir"
    return 1
  fi

  # Move bare repo in place
  if ! mv "$temp_dir/.git" .git; then
    echo "✗ Failed to move bare repo"
    mv .git.old .git  # Restore
    rm -rf "$temp_dir"
    return 1
  fi

  # Remove working tree files (they'll be in the worktree)
  # Keep only .git directory
  find . -maxdepth 1 ! -name '.git' ! -name '.git.old' ! -name '.' -exec rm -rf {} + 2>/dev/null

  # 4. Create worktree for current branch
  echo "Creating worktree for $current_branch..."
  if ! wt switch "$current_branch"; then
    echo "✗ Failed to create worktree"
    echo "↳ Restoring original repo..."
    rm -rf .git
    mv .git.old .git
    # Restore working files
    git checkout -- .
    return 1
  fi

  # 5. Success - cleanup (use absolute paths since wt switch changed pwd)
  rm -rf "$repo_root/.git.old" "$temp_dir"

  # Find the worktree path
  worktree_path=$(git worktree list | grep "\[$current_branch\]" | awk '{print $1}')

  echo "✓ Converted to bare layout"
  echo "✓ Bare repo: $repo_root/.git"
  echo "✓ Worktree: $worktree_path"
  echo "↳ Run: cd $worktree_path"
}
alias gco='git checkout'
alias gcoo='git checkout --'
alias gf='git fetch'
alias gi='git init'
alias gl='git log --graph --pretty="format:%C(yellow)%h%Creset %C(red)%G?%Creset%C(green)%d%Creset %s %Cblue(%cr) %C(bold blue)<%aN>%Creset"'
alias gll='git log --pretty="format:%C(yellow)%h%Creset %C(red)%G?%Creset%C(green)%d%Creset %s %Cblue(%cr) %C(bold blue)<%aN>%Creset"'
alias gL='gl --stat'
alias gp='git push'
alias gpl='git pull --rebase --autostash'
alias gs='git status --short .'
alias gss='git status'
alias gst='git stash'
alias gr='git reset HEAD'
alias grv='git rev-parse'

# gh cli
ghf() {
	gh repo fork $1 --clone=true --remote=true
}

# Quick PR status overview
ghprs() {
	echo "=== PRs requesting your review ==="
	gh lr || echo "No PRs requesting review"
	echo "\n=== Your assigned PRs ==="
	gh lpr || echo "No assigned PRs"
	echo "\n=== Your recent PRs ==="
	gh pr list --author @me -L 5 || echo "No recent PRs"
}

# Merge PR and cleanup
ghmr() {
	if [ -z "$1" ]; then
		echo "Usage: ghmr <PR-number>"
		return 1
	fi
	gh pr merge $1 --squash --delete-branch && git pull
}
