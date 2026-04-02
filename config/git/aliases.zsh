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

_git_sanitize_component() {
	printf '%s' "$1" | sed -E 's/[^[:alnum:]_-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

_git_shared_checkout_root() {
	local checkout_root="${1:-.}"
	local repo_root common_dir

	repo_root=$(git -C "$checkout_root" rev-parse --show-toplevel 2>/dev/null) || return 1
	common_dir=$(git -C "$checkout_root" rev-parse --git-common-dir 2>/dev/null) || return 1

	if [[ "$common_dir" != /* ]]; then
		common_dir=$(cd "$repo_root/$common_dir" 2>/dev/null && pwd -P) || return 1
	fi

	if [[ $(basename -- "$common_dir") == ".git" ]]; then
		dirname -- "$common_dir"
		return 0
	fi

	print -r -- "$repo_root"
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

_git_resolve_branch_ref() {
	local branch="$1"
	local ref

	for ref in "upstream/${branch}" "origin/${branch}" "$branch"; do
		if git rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
			print -r -- "$ref"
			return 0
		fi
	done

	print -u2 -- "error: unable to resolve review base branch: ${branch}"
	return 1
}

_git_prepare_pr_review_checkout() {
	local target="$1"
	local checkout_root shared_root worktrees_dir metadata pr_number pr_title base_branch head_branch pr_url pr_author
	local slug worktree_path base_ref

	if ! command -v gh >/dev/null 2>&1; then
		print -u2 'error: gh not found; PR review helpers require GitHub CLI'
		return 1
	fi

	metadata=$(gh pr view "$target" \
		--json number,title,baseRefName,headRefName,url,author \
		--jq '[.number, .title, .baseRefName, .headRefName, .url, .author.login] | @tsv') || return 1
	IFS=$'\t' read -r pr_number pr_title base_branch head_branch pr_url pr_author <<<"$metadata"

	print -u2 -- "reviewing PR #${pr_number}: ${pr_title}"
	print -u2 -- "base: ${base_branch} ← head: ${head_branch}"
	print -u2 -- "url: ${pr_url}"
	print -u2 -- "author: ${pr_author}"

	checkout_root=$(git rev-parse --show-toplevel) || return 1
	shared_root=$(_git_shared_checkout_root "$checkout_root") || return 1
	worktrees_dir="$shared_root/.pi/worktrees"
	mkdir -p "$worktrees_dir" || return 1

	slug=$(_git_sanitize_component "pr-${pr_number}-${head_branch}")
	[[ -n "$slug" ]] || slug="pr-${pr_number}"
	worktree_path="$worktrees_dir/$slug"

	if [[ -e "$worktree_path" ]]; then
		if ! git -C "$worktree_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
			print -u2 -- "error: review worktree path exists but is not a git checkout: ${worktree_path}"
			return 1
		fi
	else
		git -C "$checkout_root" worktree add --quiet --detach "$worktree_path" HEAD || return 1
	fi

	(
		cd "$worktree_path" || exit 1
		gh pr checkout "$target" --detach --force >/dev/null
	) || return 1

	base_ref=$(_git_resolve_branch_ref "$base_branch") || return 1
	_GIT_REVIEW_PR_WORKTREE="$worktree_path"
	_GIT_REVIEW_PR_BASE_REF="$base_ref"

	print -u2 -- "using local review checkout: ${worktree_path}"
}

_git_review_helper() {
	local tool="$1"
	local mode="$2"
	shift 2

	if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
		cat <<EOF
Usage: ${tool}pr [pr-number|branch|url] [-- ${tool} args...]

Without a PR target, review the current checkout against upstream or origin.
With a PR target, update a local .pi/worktrees checkout via \`gh pr checkout\`
and review it natively for speed.

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

	if [[ -z "$target" ]]; then
		local base_ref
		base_ref=$(_git_review_base_ref) || return 1
		print -u2 -- "reviewing local diff against ${base_ref}"

		case "$mode" in
			critique)
				_git_critique_bin "$@" "$base_ref" HEAD
				;;
			hunk)
				_git_hunk_bin diff "$@" "$base_ref"
				;;
			*)
				print -u2 -- "error: unknown review helper mode: $mode"
				return 1
				;;
		esac
		return $?
	fi

	_git_prepare_pr_review_checkout "$target" || return 1

	case "$mode" in
		critique)
			(
				cd "$_GIT_REVIEW_PR_WORKTREE" || exit 1
				_git_critique_bin "$@" "$_GIT_REVIEW_PR_BASE_REF" HEAD
			)
			;;
		hunk)
			(
				cd "$_GIT_REVIEW_PR_WORKTREE" || exit 1
				_git_hunk_bin diff "$@" "$_GIT_REVIEW_PR_BASE_REF"
			)
			;;
		*)
			print -u2 -- "error: unknown review helper mode: $mode"
			return 1
			;;
	esac
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
