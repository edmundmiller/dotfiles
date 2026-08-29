---
purpose: Operate and recover meshify's rigorously reproducible Omarchy state.
applies_to: Restoring, checking, snapshotting, or updating Omarchy on meshify.
entrypoint: Run `./manage check`, then use the matching `manage` subcommand.
verification: Run the temporary-home drill and a full live `./manage check`.
update_when: State ownership, dependencies, plugins, secrets, restore behavior, or known recovery hazards change.
---

# Meshify Omarchy recovery

This directory is the source of truth for meshify's user-owned Omarchy state.
Omarchy continues to own its packaged defaults under `/usr/share/omarchy/`.
ADR 0011 defines the recovery boundary.

## Supported interface

```bash
cd ~/.config/dotfiles/hosts/meshify/omarchy
./manage restore
./manage check
./manage snapshot
./manage update
```

- `restore` installs the declared files, exact plugin revisions, packages,
  plugin setup, private state, and keyring entries. It is idempotent and ends
  with `check`.
- `check` is read-only. It detects file and mode drift, unknown active paths,
  package or command gaps, plugin drift, disabled plugins, service failures,
  missing private state, keyring absence, Omarchy incompatibility, shell
  availability, and Hyprland errors.
- `snapshot` copies only allowlisted non-secret files from the live home into
  Git. It refuses to run while an active path is unclassified.
- `update` fetches plugin changes, displays their commits and diff statistics,
  requires confirmation, validates them, and advances `plugins.lock.json`.
  Review third-party source before confirming an update.

Mutating commands use a host-local lock. Changed live files are backed up under
`~/.local/state/meshify-omarchy/backups/`. Interrupted secret reads are bounded
and their protected temporary files are removed on the next restore.

Useful options:

```text
--home PATH   target another home directory
--no-system   skip host packages, services, shell IPC, and Hyprland operations
--no-secrets  do not read 1Password or inspect the system keyring
--yes         confirm reviewed plugin updates non-interactively
```

## Sources of truth

- `manifest.json` declares file mappings and modes, packages, services, private
  state, manual recovery gates, the tested Omarchy version, and inventory
  classifications.
- `plugins.lock.json` declares plugin IDs, URLs, exact commits, enablement, and
  trusted setup adapters.
- `config/` and `local/` contain safe desired state.
- The 1Password item described below owns private files and credentials.
- `/usr/share/omarchy/` owns stock branding, extension templates, sample hooks,
  and packaged defaults.

Plugin repositories, build output, logs, backups, lock files, and session state
are generated and intentionally excluded from Git. AirPods hardware pairing is
a documented human recovery gate rather than exported secret material.

## Steam game idle policy

Fullscreen Steam games inhibit the screensaver, lock, and suspend because
game-controller input does not reset Hyprland's idle timer.

## Rocket League autostart

`local/bin/rocket-league-autostart` starts Rocket League at login. Steam can
consume the first launch URI while applying startup updates, so the launcher
retries every 15 seconds for up to 10 minutes and stops once the game runs.
The retry behavior is covered by:

```bash
python3 tests/test_meshify_rocket_league_autostart.py
```

Generate the current plugin inventory instead of copying it into documentation:

```bash
jq -r '.plugins[] | [.id, .url, .revision] | @tsv' plugins.lock.json
```

## Known issue: plugin reloads while locked

On Omarchy `4.0.0-1` with `quickshell-git 0.3.0.r20.g28771c7-1`, writing
inside `~/.config/omarchy/plugins/` while the session is locked can abort the
shell. The recursive plugin watcher starts a full plugin reload, which destroys
the active `omarchy.lock` service. A later lock recovery reaches
`WlSessionLock::updateSurfaces()` without an active lock and Quickshell aborts
with:

```text
FATAL: Tried to show lockscreen surfaces without active lock
```

This happened on meshify on 2026-08-22 while Omapods setup generated many files
under `daemon/build/`. Three coredumps had the same `SIGABRT` and symbolized
stack. Memory exhaustion was ruled out, Quickshell restarted automatically, and
there was no evidence of user-data loss.

Until the tracked fix ships:

- Keep meshify unlocked while running `./manage restore` or `./manage update`.
  A changed Omapods revision can run its trusted setup adapter and write build
  output inside the watched plugin checkout.
- Do not build, edit, synchronize, or run Git operations in a local plugin while
  the screen is locked.
- For a manual Omapods build, keep generated files outside the plugin tree:

  ```bash
  src="$HOME/.config/omarchy/plugins/io.github.thisisgm.omapods/daemon"
  build="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-build/omapods"
  cmake -S "$src" -B "$build" -G Ninja -DBUILD_TESTING=OFF
  cmake --build "$build"
  cmake --install "$build" --prefix "$HOME/.local"
  ```

Do not patch `/usr/share/omarchy/`; it is package-owned and an update will
replace local changes. Track the downstream fix in
[basecamp/omarchy#7106](https://github.com/basecamp/omarchy/issues/7106) and the
Quickshell assertion in
[quickshell-mirror/quickshell#962](https://github.com/quickshell-mirror/quickshell/issues/962).
After an Omarchy update claims the fix, verify the installed version and check
for recurrence with `coredumpctl list quickshell` before removing this warning.

## 1Password recovery item

Create a secure item named `meshify-omarchy` in the `Private` vault. Add these
concealed or multiline fields using the 1Password desktop application:

| Field                     | Contents                                             |
| ------------------------- | ---------------------------------------------------- |
| `hass-config`             | Entire `~/.config/omarchy/hass/config.json` file     |
| `hass-token`              | Home Assistant long-lived access token               |
| `ai-usagebar-config`      | Entire `~/.config/ai-usagebar/config.toml` file      |
| `ai-usagebar-credentials` | Entire `~/.config/ai-usagebar/credentials.json` file |

The references are declared in `manifest.json`. Do not commit the resolved
values. Restore writes private files with mode `0600`; the Home Assistant token
is streamed to `secret-tool` on stdin and never appears in argv or command
output.

If 1Password is locked or an item is absent, restore preserves existing live
private state and reports warnings. A fresh host remains partially recovered
until the item is available. Initial 1Password login and AirPods pairing stay
human steps.

## Fresh-host restore

1. Install the Omarchy version declared by `.omarchy.version` in
   `manifest.json`.
2. Clone this repository to `~/.config/dotfiles`.
3. Sign in to the 1Password CLI through the desktop application.
4. Run:

   ```bash
   cd ~/.config/dotfiles/hosts/meshify/omarchy
   ./manage restore
   ```

5. Complete any reported manual recovery gates, then rerun `./manage check`.

Do not copy plugin repositories or generated binaries from a previous home.
Restore rebuilds them from the lockfile.

## Safe snapshot workflow

After intentionally changing a tracked Omarchy or Hyprland setting:

```bash
cd ~/.config/dotfiles/hosts/meshify/omarchy
./manage snapshot
./manage check

git diff -- config local manifest.json plugins.lock.json
```

Snapshot never reads declared private files. An unknown file under an inventoried
configuration root must be classified in `manifest.json` before snapshot can
continue.

## Temporary-home regression drill

This exercises file installation and exact plugin checkout without reading live
private state or changing host services:

```bash
cd ~/.config/dotfiles/hosts/meshify/omarchy
test_home=$(mktemp -d)
./manage restore --home "$test_home" --no-system --no-secrets
./manage check --home "$test_home" --no-system --no-secrets
rm -rf "$test_home"
```

The automated CLI regression suite uses isolated local plugin repositories:

```bash
cd ~/.config/dotfiles
python3 tests/test_meshify_omarchy_manage.py
```

## Live verification

```bash
cd ~/.config/dotfiles/hosts/meshify/omarchy
./manage check
systemctl --user is-active librepods.service
hyprctl configerrors
```

`manage check` is authoritative. A successful result may include informational
manual gates, but it must contain no errors. Restore warnings about unavailable
1Password fields mean existing state was preserved, not that a fresh private
state recovery was proved.
