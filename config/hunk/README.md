# Jev review ordering

The `jev-priority.ts` Hunk extension uses TypeSafe's Jev model to score changed
files for review priority. It orders consequential behavior changes first,
then implementation, supporting tests/docs, and mechanical changes. This is a
review-order suggestion, not a correctness or security assessment, and does not
reproduce Amp's private ranking algorithm.

The patched Nix package includes this extension alongside `hunk-commit-log`.
Its wrapper loads an immutable extension directory through Hunk's documented
`--extension` option for review and custom extension commands. Built-ins that
do not load extensions, such as `skill`, `completion`, `extension`, and `session`,
run without package-injected flags. Home Manager installs only the user config, not extension
files. The `hunkdiff` alias uses the same wrapper, including respawned reviews.
These remain user extensions, so `--no-extensions` disables both and
`--disable-extension jev-priority` disables only ranking. See the
[Hunk extension documentation](https://www.hunk.dev/docs/extend/extensions/).

Resumed reviews use the current invocation's explicit extension paths instead of
saved paths from an older package. Pass any one-off `--extension` paths again
when resuming. Extension enablement is also invocation-scoped: saved master-off
and per-ID settings are ignored. Current user/repository configuration and CLI
flags decide which extensions load. Repeat `--no-extensions` or individual
`--disable-extension` flags when resuming if you still want those extensions off.
Put bootstrap flags before `resume`, for example `hunk --no-extensions resume`.

Jev stays dormant unless you explicitly enable it for the process, with
`TYPESAFE_API_KEY` already supplied through your shell's secret manager:

```sh
HUNK_JEV_PRIORITY=1 hunk diff
```

Without activation, load the repository source directly:

```sh
HUNK_JEV_PRIORITY=1 hunk diff --extension /absolute/path/to/dotfiles/config/hunk/jev-priority.ts
```

This opt-in sends the changed paths, diff statistics, and sampled patches to
`https://api.typesafe.ai/v1/systemone`. Do not enable it for reviews containing
secrets or code you cannot disclose to TypeSafe. Repository config cannot enable
the upload or change its endpoint. It uses TypeSafe directly, not OpenRouter.
`HUNK_JEV_MODEL` optionally selects a Jev version instead of `jev-latest`.

Each load scores all files together in one request. Patches share a 16,000-character
budget, with at most 4,000 characters per file, sampled from both ends and marked
as incomplete. Reviews above 64 files or requests above 64 KB keep their existing
order with a warning. Requests, including response-body reads, time out after two
seconds, leaving headroom before commit navigation's four-second deadline. Slow
scoring falls back to the incoming order rather than delaying navigation. Missing credentials,
API errors, and incomplete scores also preserve the entire incoming order.

The extension overrides sidecar ordering; score ties retain that order. It keeps
the original file objects and IDs, so Hunk retains its navigation and source
loading behavior. Files with the same destination path share their first
occurrence's score, preserving their relative order even across renames.

Within an extension instance, refresh/watch shares the latest attempt when evidence,
model, and credentials are unchanged, including pending requests and failures. A failed attempt warns once;
unchanged refreshes retain their incoming order without another upload. Changing
the evidence, model, or API key permits another attempt. Restart Hunk to retry an
unchanged failed review. The memory-only cache also resets when a session reload
recreates the extension. Returning to a different review can trigger a new request
because only the latest is kept.

Run the behavior tests with `bun test config/hunk/jev-priority.test.ts`.
`hey check config/hunk modules/shell/git overlays/hunk` also runs the deployed
extension compatibility check against the pinned Hunk package.
