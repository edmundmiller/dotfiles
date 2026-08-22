---
purpose: Define rigorous, reproducible recovery for meshify's Omarchy configuration.
applies_to: Meshify Omarchy state, plugins, dependencies, secrets, restore tooling, and checks.
entrypoint: Use the host-local manage command specified here instead of copying files ad hoc.
verification: Exercise temporary-root restore tests and run the live meshify check after restoration.
update_when: Omarchy state ownership, plugin installation, secret recovery, or restore guarantees change.
---

# ADR 0011: Make meshify's Omarchy configuration rigorously reproducible

## Status

Accepted; implementation planned

## Date

2026-08-22

## Context

Meshify now records its active Hyprland overrides, Omarchy shell layout, helper
scripts, plugin source URLs, and plugin-specific setup instructions under
`hosts/meshify/omarchy/`. This is enough to reconstruct a useful desktop, but it
is not yet a rigorous recovery system:

- plugin restores clone the latest revision instead of the tested revision;
- restoration is a documented sequence rather than an idempotent command;
- several active, non-secret Omarchy files are not classified or captured;
- Home Assistant, AI Usage, and AirPods can own private or secret state outside
  the tracked shell configuration;
- checks compare selected files but do not prove a fresh restore works;
- generated state, packaged defaults, private state, and desired state do not
  yet have explicit owners.

The goal is functional determinism: from a fresh compatible Omarchy install, a
user can clone this repository, authenticate to 1Password, run one restore
command, and recover the same intended desktop behavior. Byte-for-byte recovery
of caches, logs, generated files, and the entire Arch installation is not the
goal.

## Decision

Treat meshify Omarchy recovery as one host-local module with a small interface:

```bash
hosts/meshify/omarchy/manage restore
hosts/meshify/omarchy/manage check
hosts/meshify/omarchy/manage snapshot
hosts/meshify/omarchy/manage update
```

The implementation may use helper files internally, but these four commands are
the supported interface for callers and tests.

### State ownership

Every relevant path must belong to exactly one class:

1. **Desired state in Git**: safe user overrides, bar layout, default agent,
   custom branding, menu extensions, active hooks, helper scripts, package
   requirements, and restore metadata.
2. **Private or secret state in 1Password**: credentials, tokens, and private
   application configuration that should not enter Git. Secret values must move
   through stdin or protected files and must never be printed by restore or
   check commands.
3. **Omarchy-owned defaults**: stock files supplied by the compatible installed
   Omarchy version. These are regenerated from `/usr/share/omarchy/`, not copied
   into the repository.
4. **Generated state**: plugin checkouts, build directories, installed binaries,
   systemd links, caches, logs, backups, and session state. Restore rebuilds
   these from declared inputs; snapshot excludes them.
5. **Manual recovery state**: hardware-bound or bootstrap state that cannot be
   restored safely, such as the initial 1Password login or AirPods re-pairing.
   Check must report the required action instead of claiming full recovery.

Unknown active files are an error during snapshot or check until they are
classified. This prevents silent gaps from accumulating.

### Repository shape

Evolve the existing directory toward:

```text
hosts/meshify/omarchy/
├── manifest.json
├── plugins.lock.json
├── config/
├── local/
├── manage
└── README.md
```

`manifest.json` records safe file mappings, required commands and packages, the
tested Omarchy compatibility range, and explicit manual recovery checks.
`plugins.lock.json` records each plugin's ID, source URL, exact commit, enablement,
and known setup requirement. Setup behavior must be handled by trusted restore
code rather than arbitrary shell fragments embedded in the manifest.

The existing `plugins.txt` remains transitional state and is replaced once the
lockfile and restore command cover its behavior.

### Command behavior

- `manage restore` is idempotent. It installs missing dependencies, clones or
  updates plugins to locked commits, runs known setup adapters, installs tracked
  files with explicit modes, restores approved 1Password-backed state, enables
  required user services, reloads affected runtimes, and finishes by running
  `manage check`.
- `manage check` is read-only. It reports file drift, unknown active files,
  missing dependencies, plugin revision or enablement drift, inactive services,
  unavailable secret-backed integrations, incompatible Omarchy versions, shell
  configuration errors, and Hyprland configuration errors.
- `manage snapshot` captures only allowlisted non-secret state. It refuses known
  credential and private-state paths and reports unclassified paths for a human
  decision.
- `manage update` intentionally advances plugin locks, reruns plugin validation
  and focused tests, updates the live installation, and leaves a reviewable Git
  diff. Ordinary restore never advances a lock.

### Secret and private-state policy

Home Assistant tokens remain in the system keyring. Home Assistant private
configuration and AI Usage configuration or credentials must either be restored
from designated 1Password items or remain explicit manual recovery steps until
a secret-safe adapter exists. AirPods pairing material is re-created by pairing
unless a separate decision approves secure export and restoration.

The repository may record 1Password references and field names, but never their
resolved values. A locked or unavailable 1Password session causes a clear
partial-recovery result, not silent omission and not deletion of existing live
state.

### Reproducibility boundary

Plugin commits are exact. Safe configuration files and modes are exact. Arch
package names and compatibility checks are declarative, but exact package bytes
are not pinned because this repository is not an Arch repository snapshot or an
OS image. The tested Omarchy version is recorded; incompatible versions fail or
require an explicit migration rather than being silently accepted.

This recovery path remains separate from meshify's historical NixOS
configuration. Implementing it must not require a Nix rebuild or move Omarchy
state into Nix modules.

## Implementation plan

### Phase 1: Inventory and lock

- Classify every active path under `~/.config/omarchy` and adjacent plugin state.
- Add `manifest.json` and `plugins.lock.json` with schema validation.
- Record the currently installed plugin commits before advancing any plugin.
- Add repository checks for duplicate IDs, missing revisions, invalid paths,
  unsafe file modes, and unavailable locked commits.

### Phase 2: Restore and live check

- Add the `manage` command with idempotent `restore` and read-only `check`.
- Replace the README's ad hoc restore loop with the command interface.
- Cover AI Usage package installation, Omarchy Pods build/service setup, plugin
  enablement, file installation, shell reload, and Hyprland validation.

### Phase 3: Safe snapshot coverage

- Capture active non-secret files that differ from Omarchy defaults.
- Add allowlists and denylists so snapshot cannot collect credentials, logs,
  backups, build output, or session state.
- Treat newly discovered active paths as unclassified failures.

### Phase 4: 1Password recovery

- Define the minimum 1Password items and fields needed for Home Assistant and AI
  Usage recovery.
- Restore keyring values through stdin and private files with owner-only modes.
- Preserve existing live secrets when 1Password is locked or unavailable.
- Keep bootstrap login and hardware pairing as explicit human gates.

### Phase 5: Regression proof

- Restore into a temporary home/root without mutating the live desktop.
- Assert installed paths, modes, plugin commits, shell layout, and generated
  plans against fixtures.
- Run live smoke checks for plugin discovery, required services, Omarchy shell
  errors, and `hyprctl configerrors`.
- Document and periodically perform a fresh-host recovery drill.

## Consequences

Positive:

- Recovery has one stable interface instead of a growing list of copy commands.
- Plugin updates become intentional and reviewable.
- Secret ownership is explicit and cannot be confused with Git-managed state.
- Temporary-root tests can catch restore regressions without damaging the live
  desktop.
- Checks expose partial recovery and drift instead of overstating success.

Tradeoffs:

- The manifest, lockfile, adapters, and tests require ongoing maintenance when
  Omarchy or plugins change.
- Reproducibility is limited to the declared desktop configuration boundary, not
  exact Arch package bytes or hardware state.
- 1Password remains a human bootstrap dependency.
- Some private application state may remain manual until a safe adapter is
  implemented and tested.

## Rejected alternatives

### Commit the entire `~/.config/omarchy` directory

Rejected because it would mix desired state with plugin source, generated files,
logs, backups, private identifiers, and potentially secret-bearing state. It
would also duplicate stock Omarchy files and make upgrades harder to reason
about.

### Track only plugin URLs and always restore the latest revision

Rejected because a URL without a commit cannot reproduce the tested system and
can introduce unreviewed behavior during disaster recovery.

### Put the recovery path into meshify's NixOS modules

Rejected because the active system is Omarchy, the user explicitly wants this
work independent of NixOS, and a Nix rebuild should not be required to recover
user-level Omarchy state.

### Back up a raw home-directory archive

Rejected as the primary mechanism because an archive obscures ownership,
contains stale generated state, is difficult to review, and provides weak drift
or compatibility diagnostics. An encrypted archive may supplement recovery, but
it is not the source of truth.

## Verification and completion criteria

This ADR is implemented when all of the following are exercised successfully:

1. `manage restore` completes twice without unintended changes.
2. A temporary-root restore passes without reading live private state.
3. `manage check` detects modified tracked files, plugin revision drift, missing
   dependencies, inactive required services, incompatible Omarchy versions, and
   unclassified active paths.
4. Secret-backed restoration does not print resolved values and preserves live
   values when 1Password is unavailable.
5. A fresh-host drill restores the shell layout and plugins, then reports only
   documented human gates.
6. The repository is clean after restore and check when live state matches the
   declared state.
