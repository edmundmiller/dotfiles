# Worklog: herdr-worktree-events

Status: blocked

## Objective

Document Herdr 0.7.5 worktree lifecycle from official sources, replace any superseded
`post_create_command` guidance, and identify repo-owned workflows that should use
`worktree.created`. Stop after focused validation, review, publication, and upstream
equality proof.

## Decisions

- Work in a clean sibling Git worktree because canonical `main` contains unrelated NUC edits.
- Treat `worktree.created` plugin events as the durable post-create automation surface.
- Keep the existing layout plugin subscribed to both `workspace.created` and
  `worktree.created`: either lifecycle can create the first shell pane, and its workspace
  lock plus idempotent reconciliation prevent duplicate layout.
- Do not subscribe smart rename to worktree events; it names workspace/tab state.
- Reserve `worktree.opened` for future rehydration and `worktree.removed` for future
  plugin-owned cache cleanup. Neither has a current repo-owned consumer.
- Update the packaged Herdr skill because its 0.7.5 agent examples still used removed
  `agent send` and generic `wait` forms.

## Evidence

- Official Herdr 0.7.5 changelog and tagged source establish the live agent CLI and event
  order. Official socket docs establish `worktree.created`, `worktree.opened`, and
  `worktree.removed`.
- Installed schema exposes `worktree.created`, `worktree.opened`, `worktree.removed`,
  `agent.prompt`, `agent.wait`, and `pane.wait_for_output`.
- `uv run --with pytest pytest tests/test_herdr_skill.py
tests/test_herdr_plugin_packaging.py
packages/herdr-plugins/dotfiles-dev-layout/dev_layout_test.py -q`: 18 passed.
- `nix-instantiate --parse modules/shell/herdr/default.nix`: passed.
- Tracked config validated with isolated `XDG_CONFIG_HOME`: `config: ok`.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` built the new system
  and Home Manager outputs, then failed in unrelated Homebrew cask fetches:
  `vlc` has an invalid `command_wrapper`; `inkscape` also failed to fetch.
- Direct activation of the newly built Home Manager output succeeded. Live verification:
  `herdr 0.7.5`, `herdr config check` is `config: ok`, no `post_create_command`, and
  `diff -qr` reports the installed Herdr skill equals the tracked source.
- `git diff --check`: passed.

## Reviews

- Plan gate not required: documentation and narrowly scoped plugin lifecycle work are not high risk.
- Commit hooks passed for all implementation and documentation commits.
- First `hey agent-finish` attempt rejected the intermediate `Status: validation` value
  and formatted this worklog. Corrected to the supported active status before rerun.
- `hey agent-audit-tests`: `PASS test-confidence`.
- `hey agent-finish --worklog .agents/worklogs/herdr-worktree-events.md`: all
  applicable repository gates passed.
- Heterogeneous landing review is blocked: both the default Claude reviewer and one
  Gemini fallback returned `RUNTIME: Authentication required`.

## Feedback

None yet.

## Remaining work

- Authenticate one non-GPT ACP reviewer, then rerun `hey agent-review landing
--active-model-family gpt-5.6 --worklog
.agents/worklogs/herdr-worktree-events.md` (add `--reviewer gemini` if that is the
  authenticated provider).
- Resolve findings; mark this worklog complete; rebase, publish, and verify upstream
  with the `done` skill.

## Commits

- `e9553cba6 test(herdr): capture 0.7.5 CLI regression`
- `c47a17bc1 fix(herdr): teach the 0.7.5 agent CLI`
- `1315eeb06 docs(herdr): map the worktree event lifecycle`
