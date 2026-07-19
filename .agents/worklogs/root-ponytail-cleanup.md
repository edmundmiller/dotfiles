# Worklog: root-ponytail-cleanup

Status: complete

## Objective

Remove the approved root/package complexity, preserve zsh-bench as a package-owned patched upstream source, and finish when focused package, Linux, Darwin, repository, and runtime checks pass and the branch is current upstream.

## Decisions

- Remove agent-fleet entirely, including its public flake package and quality-audit path.
- Remove `modules/shell/ai.nix` and host `shell.ai` blocks. Agent CLIs remain via `modules.agents.*`.
- Remove the public `full` template only; keep `devShells.full`.
- Remove the non-blocking tech-debt scanner as an approved capability cut.
- Keep zsh-bench only through `packages/`; carry the root `script --` fix as a patch.
- Drop root dead files: p10k scripts, `darwin.nix`, `systems/default.nix`, `research.md`, `notes.org`, `skills-lock.json`, `.jj-opencode.json`.
- Drop unused flake `llm-prompt` input and unused `pkgs'` binding.
- Remove empty Darwin-only filtering and dedupe Darwin host construction.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin 27.0.0 arm64.
- Root `zsh-bench` differed from packaged upstream by one line: `script -fqec … -- "$1"`.
- Packaged `zsh-bench` with BSD `script --` patch; harness relative paths; `hey zbench` smokes from PATH (`/etc/profiles/per-user/emiller/bin/zsh-bench`).
- Hosts mactraitorpro/nuc/seqeratop: `shell.ai` removed with module.
- NUC staged diff AI-only; unstaged HASS_URL/HA_URL betty env restored byte-for-byte vs prior session capture.
- `nix eval` Seqeratop + MacTraitor-Pro primaryUser OK.
- `hey nuc-wt dry-activate` OK → `/nix/store/q74sjq9l37h1p5l0qpi5n8arfrag6giy-nixos-system-nuc-26.11.20260714.18b9261`.
- `hey check --worktree` PASS (fmt, hooks, tmux, package harness/policy, ast-grep).
- Inventory YAML via `bin/agent-quality` generator; `.pi/skills/zbench` path updated.
- Darwin `switch` once succeeded after temporary lgtm hash; **restored** `packages/lgtm.nix`. Pre-existing drift blocks future switch: specified `sha256-gIXmb…CWs=` got `sha256-didBO1…27A=`. Out of scope.
- Live ref grep clean aside from unrelated `flake.nix` `nix-systems/default` input URL.

## Reviews

- Plan: `hey agent-review plan --active-model-family grok --reviewer opencode`.
  - Claude/Gemini/Pi/Codex ACP auth failed; OpenCode succeeded.
  - F1: template-only removal of `full` (devShell stays).
  - F2: update `zbench.nu` with root script removal; package the `script --` patch.
  - F3–F5 accepted; F4 wrong on host enablement — hosts do enable `shell.ai`; remove those blocks with the module.
  - F6 verification: package build, zbench smoke, Linux dry-activate via `hey nuc-wt`, Darwin rebuild attempt, `hey check`.

## Feedback

- ACP plan/landing reviewers still mostly auth-blocked; OpenCode is the working heterogeneous path.
- Do not “fix” unrelated mutable-download hash drift to green a Darwin switch; report and leave.

## Remaining work

- None for this cleanup. Unrelated: `packages/lgtm.nix` hash drift; unstaged NUC HASS/hermes/mo dirt.

## Commits

- `4624c0aea` refactor(zsh-bench): package-owned upstream with BSD script patch
- `2a08a29e9` chore: remove agent-fleet package and quality path
- `9aa89b48c` refactor(shell): remove unused shell.ai module
- `9cff71faf` chore: cut dead root files and simplify flake hosts
