# Tmux sources

Runtime wiring and startup ownership are documented in
[the tmux module](../../modules/shell/tmux/AGENTS.md). Edit scripts/config here;
the module generates `extraInit` and launcher helpers.

Run `hey ztest` for affected shell tests, then run `hey check` on `config/tmux`
and `modules/shell/tmux`. Test launchers in a disposable tmux server rather than
replacing the user's live session.
