# nix-direnv cache health

Use this when `cd` into dotfiles or `direnv export` feels slow.

## Healthy state

```bash
ls -l ~/.config/direnv/direnvrc
rg 'nix-direnv|use flake' ~/.config/direnv/direnvrc .envrc
direnv status
direnv exec . true
find .direnv -maxdepth 2 -name 'flake-profile-*' -ls
nix-store --query --roots "$(readlink .direnv/flake-profile-*)"
```

Expected signs:

- `~/.config/direnv/direnvrc` is the home-manager symlink and sources nix-direnv.
- `.envrc` contains `use flake`.
- warm loads log `nix-direnv: Using cached dev shell`.
- `.direnv/flake-profile-<hash>` symlinks to `/nix/store/...-nix-shell-env`.
- `nix-store --query --roots` shows the `.direnv/flake-profile-<hash>` symlink as a GC root.

## Timing

```bash
for i in 1 2 3; do
  DIRENV_LOG_FORMAT='%s' /usr/bin/time -p direnv exec . true 2>&1 \
    | rg 'nix-direnv|real|development shell|using flake|cache'
done
```

On 2026-05-25, this dotfiles worktree measured:

- first miss after missing `.direnv/flake-profile-*`: ~14.0s
- warm cached loads: ~0.19-0.22s

## Common invalidations

nix-direnv renews the cache when watched files are newer than the cached rc, or
when the profile symlink/rc is missing. For this repo, the usual watched files
are:

- `.envrc`
- `~/.config/direnv/direnvrc`
- `flake.nix`
- `flake.lock`

So cold/miss cases are expected after flake edits, lock updates, changing the
Nix-managed direnvrc, deleting `.direnv`, or GC removing unrooted store paths.
Do not delete `.direnv` or run destructive GC just to diagnose latency.

## Reading the cause

Run one load with logs enabled:

```bash
DIRENV_LOG_FORMAT='%s' direnv exec . true
```

Useful messages:

- `Using cached dev shell`: cache hit.
- `cache invalidated: profile ... does not exist`: local `.direnv` profile was missing.
- `cache invalidated: files newer than cache`: one of the watched inputs changed.
- `Renewed cache`: nix-direnv rebuilt the shell env and wrote a new profile/rc.
