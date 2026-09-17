#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

watch_file() { :; }
source_env_if_exists() { :; }
gh() {
  [[ $* == 'auth token --hostname github.com' ]]
  case $auth in
    available) printf 'test-github-token\n' ;;
    empty) : ;;
    missing) return 127 ;;
  esac
}
use() {
  [[ $* == "$expected_args" ]]
  local expected_config=${original_config:-}
  if [[ $auth == available ]]; then
    expected_config+=$'\nextra-access-tokens = github.com=test-github-token'
  fi
  # Check the environment inherited by an external process, as Nix would.
  [[ $(bash -c 'printf "%s" "${NIX_CONFIG:-}"') == "$expected_config" ]]
  export DIRENV_TEST_SHELL_LOADED=1
}

for auth in available empty missing; do
  for configured in yes no; do
    for mode in default full light invalid; do
      (
        unset NIX_CONFIG DIRENV_TEST_SHELL_LOADED
        original_config=
        if [[ $configured == yes ]]; then
          original_config='access-tokens = git.example.com=existing-token'
          export NIX_CONFIG=$original_config
        fi
        export DOTFILES_DIRENV_MODE=$mode
        case $mode in
          default) expected_args='flake . --no-update-lock-file' ;;
          full) expected_args='flake .#full --no-update-lock-file' ;;
          invalid) expected_args='flake' ;;
        esac
        source .envrc 2>/dev/null
        [[ ${NIX_CONFIG:-} == "$original_config" ]]
        if [[ $configured == no ]]; then
          [[ ! -v NIX_CONFIG ]]
        fi
        if [[ $mode == light ]]; then
          [[ ! -v DIRENV_TEST_SHELL_LOADED ]]
        else
          [[ ${DIRENV_TEST_SHELL_LOADED:-} == 1 ]]
        fi
      )
    done
  done
done
printf 'direnv authentication and environment isolation passed\n'
