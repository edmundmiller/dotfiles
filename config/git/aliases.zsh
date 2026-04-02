#!/usr/bin/env zsh

# Route common `git diff` calls to diffs. Set GIT_DIFF_NATIVE=1 to bypass.
git() {
  if [[ "$1" != "diff" || -n "${GIT_DIFF_NATIVE:-}" ]]; then
    command git "$@"
    return
  fi

  shift
  local args=("$@")

  if ! command -v diffs >/dev/null 2>&1; then
    command git diff "${args[@]}"
    return
  fi

  case "${#args[@]}" in
    0)
      diffs
      return
      ;;
    1)
      case "${args[1]}" in
        --cached|--staged)
          diffs --staged
          return
          ;;
        *..*)
          if [[ "${args[1]}" != *"..."* ]]; then
            diffs --from "${args[1]%%..*}" --to "${args[1]##*..}"
            return
          fi
          ;;
        -*)
          ;;
        *)
          diffs --commit "${args[1]}"
          return
          ;;
      esac
      ;;
    2)
      if [[ "${args[1]}" != -* && "${args[2]}" != -* ]]; then
        diffs --from "${args[1]}" --to "${args[2]}"
        return
      fi
      ;;
  esac

  command git diff "${args[@]}"
}

g() { [[ $# = 0 ]] && git status --short . || git $*; }

alias ga='git add'
alias gap='git add --patch'
alias gb='git branch'
alias gbr='git browse'
alias gbl='git blame'
alias gc='git commit'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gca='git commit --amend'
alias gcad='git commit -a --amend'
alias gcf='git commit --fixup'
# gcl: Clone using a separate worktree hub + checkout root
# Usage: gcl <url> [name]
# Creates: name.worktree-hub/.git (bare) + name/ checkout (default branch)
gcl() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: gcl <url> [directory]"
    echo "Creates name.worktree-hub + name checkout"
    return 1
  fi

  local url=$1
  local name=${2:-$(basename "$url" .git)}
  local hub="${name}.worktree-hub"
  local cwd checkout_path
  cwd=$(pwd -P)
  checkout_path="${cwd}/${name}"

  if [[ -e "$name" || -e "$hub" ]]; then
    echo "✗ '$name' or '$hub' already exists"
    return 1
  fi

  git clone --bare "$url" "${hub}/.bare" || return 1
  mv "${hub}/.bare" "${hub}/.git"

  # Fix fetch refspec — bare clones omit this, making remote branches invisible
  git -C "${hub}/.git" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git -C "${hub}/.git" fetch

  local default_branch
  default_branch=$(git -C "${hub}/.git" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
  if [[ -z "$default_branch" ]]; then
    default_branch=$(git -C "${hub}/.git" remote show origin | awk '/HEAD branch/{print $NF}')
  fi

  git -C "${hub}/.git" worktree add "$checkout_path" "$default_branch"

  echo "✓ checkout: $name ($default_branch)"
  echo "✓ hub: $hub"
  cd "$checkout_path"
}

# g2bare: convert existing repo to bare layout IN-PLACE
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
  worktree_path="$repo_root/$current_branch"
  if ! git -C "$repo_root/.git" worktree add "$worktree_path" "$current_branch"; then
    echo "✗ Failed to create worktree"
    echo "↳ Restoring original repo..."
    rm -rf .git
    mv .git.old .git
    git checkout -- .
    return 1
  fi

  # 5. Success - cleanup
  rm -rf "$repo_root/.git.old" "$temp_dir"

  echo "✓ Converted to bare layout"
  echo "✓ Bare repo: $repo_root/.git"
  echo "✓ Worktree: $worktree_path"
  echo "↳ Run: cd $worktree_path"
  cd "$worktree_path"
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

# critique - TUI diff viewer (prefers installed binary, falls back to bunx)
unalias critique 2>/dev/null || true
_git_critique_bin() {
	if (( $+commands[critique] )); then
		command critique "$@"
	else
		bunx critique "$@"
	fi
}

_git_hunk_bin() {
	if (( $+commands[hunk] )); then
		command hunk "$@"
	else
		bunx hunkdiff "$@"
	fi
}

_git_review_base_ref() {
	local remote ref

	for remote in upstream origin; do
		git config --get "remote.${remote}.url" >/dev/null 2>&1 || continue

		ref=$(git symbolic-ref --quiet --short "refs/remotes/${remote}/HEAD" 2>/dev/null) || true
		if [[ -n "$ref" ]]; then
			print -r -- "$ref"
			return 0
		fi

		for ref in "${remote}/main" "${remote}/master"; do
			if git rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
				print -r -- "$ref"
				return 0
			fi
		done
	done

	print -u2 'error: unable to determine review base; expected upstream or origin default branch'
	return 1
}

_git_review_target_patch() {
	local target="$1"

	if [[ -z "$target" ]]; then
		local base_ref
		base_ref=$(_git_review_base_ref) || return 1
		print -u2 -- "reviewing local diff against ${base_ref}"
		git diff --patch "${base_ref}...HEAD"
		return $?
	fi

	if ! command -v gh >/dev/null 2>&1; then
		print -u2 'error: gh not found; PR review helpers require GitHub CLI'
		return 1
	fi

	gh pr view "$target" \
		--json number,title,baseRefName,headRefName,url,author \
		--jq '"reviewing PR #\(.number): \(.title)\nbase: \(.baseRefName) ← head: \(.headRefName)\nurl: \(.url)\nauthor: \(.author.login)"' \
		1>&2 || true
	gh pr diff "$target" --patch
}

_git_review_helper() {
	local tool="$1"
	local mode="$2"
	shift 2

	if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
		cat <<EOF
Usage: ${tool}pr [pr-number|branch|url] [-- ${tool} args...]

Without a PR target, review the current checkout against upstream or origin.
With a PR target, stream \`gh pr diff\` into ${tool}.

Examples:
  ${tool}pr
  ${tool}pr 123
  ${tool}pr feature-branch -- --web
EOF
		return 0
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		print -u2 'error: review helpers must be run inside a git repository'
		return 1
	fi

	local target=""
	if [[ $# -gt 0 && ${1:-} != -- && ${1:-} != -* ]]; then
		target="$1"
		shift
	fi

	if [[ ${1:-} == -- ]]; then
		shift
	fi

	local patch_file
	patch_file=$(mktemp "${TMPDIR:-/tmp}/${tool}pr.XXXXXX") || return 1
	if ! _git_review_target_patch "$target" >"$patch_file"; then
		rm -f "$patch_file"
		return 1
	fi

	case "$mode" in
		critique)
			_git_critique_bin --stdin "$@" <"$patch_file"
			;;
		hunk)
			_git_hunk_bin patch "$@" <"$patch_file"
			;;
		*)
			rm -f "$patch_file"
			print -u2 -- "error: unknown review helper mode: $mode"
			return 1
			;;
	esac

	rm -f "$patch_file"
}

critique() {
	_git_critique_bin "$@"
}

critpr() {
	_git_review_helper critique critique "$@"
}

hunkpr() {
	_git_review_helper hunk hunk "$@"
}

crpr() {
	critpr "$@"
}
alias hk='hunk'
alias hkd='hunk diff'
alias hks='hunk show'
hkpr() {
	hunkpr "$@"
}

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
