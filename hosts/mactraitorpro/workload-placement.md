---
purpose: Route development work away from MacTraitor-Pro when an Amp Orb or another host can own it.
applies_to: Choosing between Amp Orbs, MacTraitor-Pro, the NUC, and Meshify.
entrypoint: Apply the Orb eligibility rule, then use the workload matrix below.
verification: Confirm the chosen environment can run the workload's final acceptance check.
update_when: Amp Orb limits, host roles, data locations, or project acceptance requirements change.
---

# MacTraitor-Pro workload placement

MacTraitor-Pro is the interaction, review, and Apple-platform acceptance
machine. Prefer Amp Orbs for repository-contained development so agent
worktrees, dependencies, and build artifacts do not accumulate on this host.

## Mac runner setup

The [Amp Mac app](https://ampcode.com/docs/macos-and-ios/runner) owns this
host's runner. Nix no longer starts a separate `amp-runner` launchd agent.
The CLI and its sign-in remain mutable, managed by Amp.

After an authorized `hey re` removes the old launchd service, configure the
app once:

1. Install or update [Amp for macOS](https://ampcode.com/app), which requires
   macOS 26 or later.
2. Open **App Settings… → Runner** and enable **Use This Mac as a Runner**.
3. Keep **Runner Name** set to `mactraitor-pro-amp-app`, matching the runner ID
   in `config/amp/mactraitor-pro-runner.json`.
4. Run `amp-runner-sync` to preview missing registrations, then
   `amp-runner-sync --apply` to add them. The command lives in the dotfiles
   `bin/` directory and requires the app's runner to be running.
5. Leave **Keep This Mac Awake** on for availability while plugged in.

`config/amp/mactraitor-pro-runner.json` records the 125 folders restored from
the old Mac runner on 2026-09-25. Edit this list when adding repositories or
retiring worktrees. The sync command adds existing folders through
`amp runner dirs add`, skips missing paths with a warning, and preserves
registrations outside the list. Removing a list entry does not unregister it.
The command does not clone repositories, create Amp cloud projects, start a
service, or run during Nix activation. No rebuild is needed to apply the list.

The home folder is deliberately absent from the manifest. The existing app
registration is preserved, but a fresh setup will not enable **Home Folder**.
Folders added through the CLI persist across app restarts. This is an explicit
folder list, not the old service's automatic `--discover-dirs` scan.

The app finds the CLI through the login shell's `PATH`. Resolve any missing,
outdated, or unsigned-in CLI warning in the Runner tab before testing a thread.
Confirm that the runner is **Running**, that the picker marks it **This Mac**,
and that **Also Running on This Mac** does not show the retired service.

Keep the app open while using the runner. Quitting stops it. Battery power,
closing the lid, or choosing Sleep can still suspend the Mac. The app does
not promise the old service's `--remote-control-terminal` behavior.

## Amp Orb eligibility rule

Use an Amp Orb when the task can:

1. start from an accessible Git clone on Debian 12;
2. fit its checkout, dependencies, caches, and outputs within 60 GB; and
3. be verified without Apple tooling, a GPU, physical hardware, or local-only
   data.

Amp Orb sizes differ in CPU and memory, but all currently have 60 GB of disk.
Orbs can run browsers, databases, development servers, and Docker after setup.
They sleep between interactions and retain thread files, but they are
per-thread development machines rather than durable service or archive hosts.

Current sources of truth:

- [Amp Orbs](https://ampcode.com/docs/orbs)
- [Customizing Orbs](https://ampcode.com/docs/orbs/customizing)
- [Orb sizes and costs](https://ampcode.com/what-are-orbs#many-different-orbs)

Recheck those sources before relying on a resource or platform limit that may
have changed.

## Workload matrix

| Workload                                                                                                        | Default environment | Boundary                                                                                                                       |
| --------------------------------------------------------------------------------------------------------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Repository-contained coding, tests, documentation, browser E2E, and pull requests                               | Amp Orb             | Keep local checkouts only for active review or acceptance.                                                                     |
| TaskNotes Native TypeScript, React Native, documentation, and non-Apple tests                                   | Amp Orb             | Hand the branch to MacTraitor-Pro for native acceptance.                                                                       |
| TaskNotes Native Xcode builds, iOS Simulator, signing, native modules, physical-device tests, and UI acceptance | MacTraitor-Pro      | Amp Orbs run Debian and cannot provide Xcode or Apple device tooling.                                                          |
| Dotfiles editing and host-independent checks                                                                    | Amp Orb             | Source work is not inherently laptop-only.                                                                                     |
| nix-darwin activation, Homebrew, 1Password-backed interaction, and macOS application state                      | MacTraitor-Pro      | Run the final host check and `hey re` here.                                                                                    |
| NUC NixOS builds, deployment, persistent services, ZFS, Home Assistant, and home-LAN integration                | NUC                 | Use the repository's `hey nuc-wt` or `hey nuc` path; verify on the NUC.                                                        |
| All `~/src/fg` work, including manuscript prose, workflow code, and lightweight checks                          | NUC                 | Use the `nuc` Amp runner and `/home/emiller/src/fg`; these repositories no longer live on the Mac.                             |
| Nascent manuscript DVC data, full analyses, and data-derived outputs                                            | NUC                 | The local checkout was about 40 GB in August 2026, including about 39 GB of DVC cache, leaving unsafe headroom on a 60 GB Orb. |
| GPU inference or compute, Vulkan, Linux desktop, Wayland, Bluetooth, and audio integration                      | Meshify             | Verification requires Meshify's GPU, desktop session, or attached hardware.                                                    |
| Trace archives, databases of record, large durable datasets, and always-on services                             | NUC                 | Do not use a per-thread Orb as permanent storage or service infrastructure.                                                    |

## Hybrid work is expected

"Cannot finish in an Orb" does not mean "cannot start in an Orb." Keep source
editing, unit tests, and review in the Orb whenever possible. Transfer the
branch or diff to the required host only for the smallest final acceptance
step. Dotfiles and TaskNotes Native both follow this model.

The `fg` repositories are an explicit exception to the Orb default: all work
stays on the NUC. The Mac's 2026-10-03 working copies, including dirty files and
DVC data, are preserved separately at `/home/emiller/src/fg-mactraitor-20261003`.
Use the existing `/home/emiller/src/fg` checkouts for Linux execution. The
preserved Mac copies contain macOS environments and absolute symlinks; they are
recovery copies, not verified Linux environments. Do not overwrite newer NUC
work with them when recovering a Mac-only change.

## Data and access boundaries

An Orb receives configured Git repositories, not arbitrary Mac state. Do not
assume it can access:

- dirty or unpushed worktrees;
- local DVC or model caches;
- iCloud or Syncthing trees;
- the full Obsidian vault;
- 1Password sessions or host-encrypted secrets; or
- services available only on the home LAN.

Move source through a verified private Git remote. Move large data only through
its approved data remote. Do not upload the full Obsidian vault merely to expose
its embedded application code; use a private code-only repository or an
explicit sanitized projection.

Amp secrets, OIDC, and Tailscale can make selected remote resources available
to an Orb, but connectivity does not move final host ownership. Shared
deployments and other external writes still require explicit approval and
verification on the target system.

Repositories with broken, missing, or unverified remotes are temporarily
ineligible for Orbs, not permanently laptop-bound. Repair and verify the remote
instead of creating another long-lived local agent worktree.
