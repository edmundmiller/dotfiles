# Jujutsu integration

`config/jj/config.toml` and `conf.d/` own templates and workflows. Default log
uses `mine()` and hides other authors' unmerged work; `jj la-all` and
`jj la-team` override that filter. `jj lh` and `jj lc` select human/credits-roll
views.

Upstream `YPares/jj.conf.d` supplies credits-roll templates.
`format_short_id(id)` accepts a ChangeId, not a Commit; use `.shortest()` on it,
not `.change_id()`. Avoid redefining upstream aliases with incompatible
signatures. Removed `format_short_change_id_with_*` aliases can be replaced by
direct ChangeId methods.

Bookmark auto-tracking uses `remotes.origin.auto-track-bookmarks`, not the
deprecated `git.auto-local-bookmark`.
