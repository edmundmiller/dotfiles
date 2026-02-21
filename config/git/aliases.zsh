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
# Creates: name/.git (bare) + name/<default-branch>/ worktree
# Clone to a non-.git path first to avoid git's core.bare=false heuristic
gcl() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: gcl <url> [directory]"
    echo "Creates a bare repository for use with worktrunk"
    return 1
  fi
  local url=$1
  local name=${2:-$(basename "$url" .git)}
  git clone --bare "$url" "${name}/.bare" || return 1
  mv "${name}/.bare" "${name}/.git"
  # Fix fetch refspec — bare clones omit this, making remote branches invisible
  git -C "${name}/.git" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git -C "${name}/.git" fetch
  # Add worktree for default branch
  local default_branch
  default_branch=$(git -C "${name}/.git" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
  if [[ -z "$default_branch" ]]; then
    default_branch=$(git -C "${name}/.git" remote show origin | awk '/HEAD branch/{print $NF}')
  fi
  git -C "${name}/.git" worktree add "${name}/${default_branch}" "${default_branch}"
  echo "✓ $name/${default_branch} ready"
  cd "${name}/${default_branch}"
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

# critique - TUI diff viewer (requires bun)
alias critique='bunx critique'

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

# Lazygit
alias lzg="lazygit"

# bd init safety: protect existing AGENTS.md; write minimal onboard stub for new ones
function bd() {
  if [[ "$1" == "init" ]]; then
    if [[ -f AGENTS.md ]]; then
      local _backup
      _backup=$(cat AGENTS.md)
      command bd "$@"
      local _rc=$?
      printf '%s\n' "$_backup" > AGENTS.md
      echo "  ↩  kept existing AGENTS.md (discarded bd's version)"
      return $_rc
    else
      command bd "$@"
      local _rc=$?
      if [[ $_rc -eq 0 && -f AGENTS.md ]]; then
        command bd onboard 2>/dev/null \
          | awk '/BEGIN AGENTS.MD CONTENT/{p=1;next} /END AGENTS.MD CONTENT/{p=0} p' \
          > AGENTS.md
        echo "  ✓  wrote minimal AGENTS.md stub (bd prime for full context)"
      fi
      return $_rc
    fi
  fi
  command bd "$@"
}
