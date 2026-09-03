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

## Focused recovery guides

- [Bluetooth and AirPods](docs/bluetooth-airpods.md): read when the adapter or
  bar state disagrees, pairing stalls, audio routing is wrong, or Omapods does
  not follow a device switch.
- [Plugin reloads while locked](docs/plugin-reload-lock-crash.md): read before
  Omapods builds, plugin updates, or other writes under the watched local plugin
  directory.

## Idle suspend policy

`config/hypr/hypridle.conf` suspends meshify after 15 minutes without user
input. Omarchy's Quickshell service still owns the earlier screensaver and lock.
Its **Stay Awake** control writes the state marker that also defers automatic
suspend; turn Stay Awake off to restore the normal idle policy.

Check the live policy without suspending:

```bash
pgrep -a hypridle
omarchy toggle idle status
```

## Lock screen wake window

`config/omarchy/plugins/edmundmiller.lock` is a supported clone of Omarchy's
built-in lock service. It keeps the password prompt and displays awake for 30
seconds after the last keyboard or pointer event instead of the stock five
seconds. This prevents the prompt from blanking again while typing after
resume. `shell.json` enables the clone and disables `omarchy.lock`.

When updating Omarchy, compare the clone with the new built-in `omarchy.lock`
before carrying the timeout customization forward.

Verify the active implementation without locking the session:

```bash
omarchy plugin list --json \
  | jq '.[] | select(.id == "omarchy.lock" or .id == "edmundmiller.lock")'
```

## Steam game idle policy

Fullscreen Steam games inhibit the screensaver, lock, and suspend because
game-controller input does not reset Hyprland's idle timer.

## Syncthing

The Syncshell bar widget monitors Meshify's user-level `syncthing.service`.
Restore installs Syncthing and enables the service. Meshify trusts the NUC as
device `AUP2DGW-DVFZ5CT-D3TU2OH-SR7AO4A-WGAVWUE-Z2WWUTE-C67Z3KO-ERF4LQN`;
the NUC's NixOS configuration declares the reciprocal pairing and owns the
folders it offers to Meshify.

Meshify's device identity is generated state. Its current ID is recorded as
`meshify` in `modules/services/syncthing.nix`. If the identity is replaced,
update that ID and redeploy the NUC before accepting its folder offers again.

Verify the local half of the pairing with:

```bash
syncthing cli show system | jq -r .myID
syncthing cli config devices list
systemctl --user is-active syncthing.service
```

## Dictation

Voxtype uses the Antlion USB microphone regardless of Bluetooth audio routing.
Hold `F9` for push-to-talk or press `Super+Ctrl+X` to toggle recording. The
restore installs the English `base.en` model, enables the user service, and
keeps media-pausing support through `playerctl`.

GPU backend selection changes a privileged package symlink and is therefore a
manual recovery gate rather than repository state. After a fresh restore, run:

```bash
sudo voxtype setup gpu --enable
systemctl --user restart voxtype.service
voxtype setup gpu --status
```

The final command must report `GPU (Vulkan)`. Verify the remaining setup with
`voxtype setup check` and `systemctl --user is-active voxtype.service`.

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
