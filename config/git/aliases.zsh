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

# g2bare: convert existing repo to bare + worktrunk layout
# Usage: g2bare [target-dir]
# Creates: target/.git (bare repo) + worktree for current branch
# Leaves original repo untouched
g2bare() {
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Not in a git repository"
    return 1
  }
  local repo_name parent target current_branch
  repo_name=$(basename "$repo_root")
  parent=$(dirname "$repo_root")
  target="${1:-${parent}/${repo_name}-new}"
  if [[ -e "$target" ]]; then
    echo "Target already exists: $target"
    return 1
  fi
  mkdir -p "$target" || return 1
  git clone --bare "$repo_root" "$target/.git" || return 1
  current_branch=$(git -C "$repo_root" branch --show-current)
  if [[ -z "$current_branch" ]]; then
    current_branch="main"
  fi
  if command -v wt >/dev/null 2>&1; then
    (cd "$target" && wt switch -c "$current_branch") || return 1
    echo "Bare repo ready at $target"
    echo "Next: copy uncommitted files, verify, remove old repo"
  else
    echo "Bare repo created at $target/.git"
    echo "Next: cd $target && wt switch -c $current_branch"
  fi
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
