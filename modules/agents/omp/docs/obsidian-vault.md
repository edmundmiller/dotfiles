---
purpose: Explain how vault:// resolves to a directory and why OMP has no vault path setting.
applies_to: Pointing vault:// at a specific Obsidian vault, or debugging wrong/refused vault:// reads.
entrypoint: vault.enabled in config/omp/config.yml and ~/Library/Application Support/obsidian/obsidian.json.
verification: Run read vault://_ and compare rootPath against the open entry in Obsidian's vault registry.
update_when: OMP gains a real vault path setting, or the Obsidian CLI changes how it selects a vault.
---

# Obsidian vault resolution

## OMP has no vault path setting

`vault.enabled` is a boolean. It only controls whether the `vault://` internal
URL resolves at all; when disabled, resolution is refused and the `vault://`
entry is omitted from the system prompt. There is no companion path key in
`~/.omp/agent/config.yml`, and `modules/agents/omp/default.nix` exposes no vault
path option.

This is by design: OMP delegates resolution to the Obsidian CLI rather than
storing a path of its own. Searching the repo or the OMP config for a vault path
setting will keep coming up empty. The path lives in Obsidian, not OMP.

## The registry is the source of truth

The Obsidian CLI reads `~/Library/Application Support/obsidian/obsidian.json`
and serves the vault whose entry has `open: true`:

```sh
jq -r '.vaults | to_entries[] | "\(.value.path)  open=\(.value.open // false)"' \
  ~/Library/Application\ Support/obsidian/obsidian.json
```

On this host the registry currently holds two entries, one of which carries
`open: true`; that is the vault the CLI serves. To repoint `vault://`, move the
flag to the desired entry.

One consequence is confirmed:

- **Obsidian must be running.** The CLI talks to the app, so `vault://` fails
  when it is closed. Add Obsidian to Login Items if `vault://` must survive a
  reboot.

Not exercised here: whether switching vaults in the Obsidian UI rewrites this
flag, and how the CLI behaves if zero or several entries are marked open. Verify
before relying on either.

## Verification

```sh
read vault://_
```

The reported `rootPath` is the directory `vault://` currently serves. Compare it
against the `open: true` entry above; they must agree. `read vault://_/README.md`
confirms content is served from the expected vault.

## This configuration is not declarative

The registry is imperative, unmanaged state outside this repository. A vault
selection made here does not survive a fresh machine and is not captured in Nix.

Making it declarative would mean adding a path option to
`modules/agents/omp/default.nix` that writes the registry entry on activation.
That is not implemented; treat the current selection as machine-local until it
is.

Verified against omp 17.2.15 on Darwin. Recheck when OMP or the Obsidian CLI
changes vault selection behavior.
