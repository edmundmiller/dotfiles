#!/usr/bin/env bash

# Hunk review popup launcher.

set -euo pipefail

# Ensure bun is in PATH (tmux popup doesn't inherit full shell PATH)
export PATH="$HOME/.bun/bin:$PATH"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Not in a git repo"
    echo "Press enter to close..."
    read -r
    exit 1
fi

resolver="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/git-worktree-cwd"
[[ -x "$resolver" ]] || resolver="$HOME/.config/dotfiles/bin/git-worktree-cwd"
if [[ -x "$resolver" ]]; then
    git_root=$($resolver ".") || {
        echo "Not in a usable checkout"
        echo "Press enter to close..."
        read -r
        exit 1
    }
else
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
fi

if [[ -z "$git_root" ]]; then
    echo "Not in a git repo"
    echo "Press enter to close..."
    read -r
    exit 1
fi

cd "$git_root" || exit 1

mode="worktree"
pass_through=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --staged|--cached)
            mode="staged"
            shift
            ;;
        --branch-committed)
            mode="branch-committed"
            shift
            ;;
        *)
            pass_through+=("$1")
            shift
            ;;
    esac
done

review_args=(diff)

case "$mode" in
    staged)
        review_args+=(--staged)
        ;;
    branch-committed)
        base_ref=""
        if upstream_ref=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
            base_ref="$upstream_ref"
        else
            for candidate in origin/main origin/master main master; do
                if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
                    base_ref="$candidate"
                    break
                fi
            done
        fi

        if [[ -n "$base_ref" ]]; then
            merge_base=$(git merge-base HEAD "$base_ref" 2>/dev/null || true)
            if [[ -n "$merge_base" ]]; then
                review_args+=("$merge_base...HEAD")
            else
                review_args+=(HEAD)
            fi
        else
            review_args+=(HEAD)
        fi
        ;;
esac

if [[ ${#pass_through[@]} -gt 0 ]]; then
    review_args+=("${pass_through[@]}")
fi

if command -v hunk >/dev/null 2>&1; then
    exec hunk "${review_args[@]}"
fi

exec bunx hunkdiff "${review_args[@]}"
