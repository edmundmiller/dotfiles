---
purpose: Explain the Nix implementations used on Linux and macOS and the trade-offs behind them.
applies_to: NixOS hosts, nix-darwin Macs, and future Nix runtime decisions.
entrypoint: Read the recommendation and current ownership before proposing a runtime change.
verification: Check declarations and locked sources against the cited upstream guidance before migration.
update_when: Nix ownership, package selection, pins, or host migration acceptance changes.
---

# Nix implementation choice

Reviewed 2026-11-22. This document records the current configuration and a
recommendation, not an approved or completed migration. Determinate is working;
there is no current incident that requires replacing it.

## Recommendation

Keep upstream Nix on the NixOS hosts and Determinate Nix on the existing Macs
for now. Prefer a supported, nixpkgs-tested release over chasing implementation
features. Fewer ownership transitions and retaining working corporate TLS are
more valuable here than making every host report the same implementation.
This is a recommendation for this fleet, not a claim that one implementation
has the lowest failure rate in general.

For NixOS, upstream Nix is already declaratively managed. Switching to Lix
would not gain daemon ownership. For a conservative baseline, prefer the
nixpkgs default `pkgs.nix` over an explicit `nixVersions.latest` selection unless
a workload needs the newer release. The repo currently selects the latter and
carries a targeted fix. Review that selection and the fix together during a
separate runtime update, rather than silently changing it in documentation.

For Darwin, keep Determinate while its Keychain integration and other macOS
services are useful. Seqeratop needs corporate CA handling. Stable Lix is the
preferred alternative if returning package, daemon and configuration ownership
to nix-darwin becomes the deciding requirement. Upstream `pkgs.nix` offers that
same declarative ownership without choosing a fork. Neither choice removes the
need to replace Nixd's macOS responsibilities first.

If a future decision favors community governance and declarative ownership over
Determinate's integration, use stable Lix from nixpkgs, not Lix main. Prove the
handover on MacTraitor-Pro before considering Seqeratop. Keep Seqeratop on
Determinate until an approved replacement for corporate CA handling works.
Do not migrate healthy servers just to match the Macs, or healthy Macs just to
match the servers.

## What this repo uses today

| Systems                       | Implementation and selection                                                                                                                                                                                                                                | Runtime owner                                                                                                                                                                                |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| NixOS, including NUC and UNAS | Upstream Nix, explicitly `pkgs.nixVersions.latest` in [default.nix](../default.nix). At the current pin this is 2.35.1, with the repo's [build-slot wakeup backport](../overlays/nix-worker-wakeups/README.md). It is not an implicit `pkgs.nix` selection. | NixOS manages the package, systemd daemon and Nix configuration through `nix.*`.                                                                                                             |
| MacTraitor-Pro and Seqeratop  | Determinate Nix. [flake.nix](../flake.nix) imports its Darwin module; [darwin-base.nix](../modules/darwin-base.nix) enables it and declares policy.                                                                                                         | The separately installed Determinate runtime and Nixd own the daemon and main `nix.conf`. nix-darwin supplies custom settings, registry, Nixd configuration and the repo's maintenance jobs. |
| Other Linux environments      | Meshify's current desktop is [Omarchy](../hosts/meshify/omarchy/README.md), not a supported NixOS deployment. The [Orb setup](../.agents/setup) preserves an available Nix installation and bootstraps one with Determinate's installer only when missing.  | Do not infer NixOS daemon ownership or an installed implementation from a Linux kernel or the installer's name. Inspect that environment separately.                                         |

The root nixpkgs input resolves to lock node `nixpkgs_8`, revision
`18b9261cb3294b6d2a06d03f96872827b8fe2698`. Its
[`lixPackageSets.stable.lix` is 2.95.2](https://github.com/NixOS/nixpkgs/blob/18b9261cb3294b6d2a06d03f96872827b8fe2698/pkgs/tools/package-management/lix/default.nix).
The [upstream Nix package set](https://github.com/NixOS/nixpkgs/blob/18b9261cb3294b6d2a06d03f96872827b8fe2698/pkgs/tools/package-management/nix/default.nix)
maps `latest` to 2.35.1. These are pin-specific facts, not promises about future
versions. Before any migration, check release support and security status.
The current Lix website illustrates 2.96.0, which this pin does not select.

The locked Determinate module is 3.24.2. That pins integration code, not the
runtime installed by the macOS package. The November 21 Chicago-time live audit
observed Determinate 3.24.2, based on Nix 2.35.3, on MacTraitor-Pro. This document
does not establish the currently running versions on either Mac or the servers.

## Comparing the choices

| Choice                            | Reasons to choose it                                                                                                                                                                                                                               | Costs and limits                                                                                                                                                                                                                                           |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Upstream Nix, normally `pkgs.nix` | The default implementation in nixpkgs/nix-darwin, with the standard ecosystem integration. Both NixOS and nix-darwin can own its package, daemon and config declaratively. It avoids vendor runtime management and a fork-specific release policy. | It does not supply Nixd's macOS integration or Determinate's stable-flakes contract. Newer upstream releases can regress too; `latest` is not a low-risk policy by itself.                                                                                 |
| Determinate Nix                   | Native Linux Builder on macOS, Keychain/corporate CA export, lazy trees and parallel evaluation, and vendor-stabilized flakes and the new CLI. These can reduce setup work and evaluation time.                                                    | On these Macs the runtime sits outside Darwin generations. Recovery crosses installer/service ownership, not just a system-profile rollback. Vendor features, update policy, telemetry and account requirements need review, especially on a work machine. |
| Stable Lix from nixpkgs           | Community governance, a correctness/stability focus, better diagnostics, and normal declarative package/daemon ownership on both NixOS and nix-darwin. Official nixpkgs builds are cached.                                                         | No Nixd Keychain exporter or Determinate Native Linux Builder. Do not assume feature parity with newer upstream or Determinate extensions. Existing-store compatibility, linked tools and real workloads still need testing.                               |

Determinate documents lazy trees and parallel evaluation as performance
features. Lix also makes performance improvements, but neither the prior audits
nor this documentation task benchmarked this repo. Do not read the table as a
measured speed or reliability ranking. Lix's correctness and error-message work
is a project focus, not proof that switching eliminates operational problems.

Determinate's Native Linux Builder uses Apple's Virtualization framework,
requires FlakeHub login, and supports ARM and x86 Linux targets. It is not the
same as nix-darwin's `nix.linux-builder`. The latter is available with managed
upstream Nix or Lix and defaults to the builder's native architecture. An ARM
builder is not automatically an x86 NUC or a replacement for its VM tests.
Builder availability is a benefit, not evidence that either Mac currently uses
it. Do not add an account or VM as part of a runtime handover.

Determinate treats flakes and the new CLI as stable product interfaces.
Upstream Nix and Lix support this flake-based repo but still require the relevant
experimental-feature settings. Vendor stabilization is not an ecosystem-wide
promise that every implementation supports the same extensions. In particular,
the repo requests `dynamic-derivations` in `flake.nix`; test its effective use and
the candidate's support rather than carrying feature flags across blindly.

## What nix-darwin actually recommends

The current [nix-darwin README prerequisites](https://github.com/nix-darwin/nix-darwin#prerequisites),
checked 2026-11-22, say both upstream Nix and Lix are supported and:

> As the official Nix installer does not include an automated uninstaller, and
> manual uninstallation on macOS is a complex process, we recommend using the
> Lix installer, which supports both flake-based and channel-based setups.

The next paragraph says nix-darwin manages Nix by default, defaults to upstream
Nix, and requires `nix.package = pkgs.lix` to keep using Lix. This is an official
installer recommendation, not a recommendation to migrate every runtime to Lix
or to uninstall an existing Determinate installation.

The current [manual's `nix.enable` entry](https://nix-darwin.github.io/nix-darwin/manual/#opt-nix.enable)
explains the ownership consequence of disabling Nix management. Standard Nix
settings and the Linux builder become unavailable, and the operator must upgrade
Nix separately. The [`nix.package` entry](https://nix-darwin.github.io/nix-darwin/manual/#opt-nix.package)
defaults to `pkgs.nix`. The online manual checked here is 26.11.f673885; the
repo locks nix-darwin at `d5bd9cd77aea4c0a8f49e7fd85545671a208ed15`.

## Declarative ownership with upstream Nix or Lix

For a managed NixOS or nix-darwin installation, the stable Lix selection is:

```nix
nix.package = pkgs.lixPackageSets.stable.lix;
```

For upstream Nix, use `nix.package = pkgs.nix`. In both cases the platform's
modules manage the runtime. NixOS's `nix.*` settings and systemd service remain
the owners on Linux; nix-darwin's `nix.*` settings and launchd service become
the owners on macOS. This is not a reason to run a generic installer on NixOS.
On non-NixOS Linux, this assignment alone has no effect unless a system module
actually consumes it and owns the daemon.

[Lix's current switching guide](https://lix.systems/add-to-config/) recommends
the nixpkgs package for released versions. `lix-module` is only recommended for
tracking main/bleeding edge, with additional build and compatibility costs.
There is no need for another flake input to use stable Lix.

Setting `nix.package` does not replace every tool linked to Nix libraries.
Review tools such as `nix-eval-jobs`, `nixpkgs-review`, deployment tools and editor
helpers separately. Use supported Lix package-set variants where needed, not a
blanket override without tests. This flake supplies preconstructed `linuxPkgs`
and `darwinPkgs`; any necessary overlay belongs in those package constructions.

On our Macs, this is a target configuration, not an additive change. The
[locked Determinate module](https://github.com/DeterminateSystems/determinate/blob/558e026d9d3c78351170d8f8a797fa0fac541ccf/modules/nix-darwin/default.nix)
sets `nix.enable = lib.mkForce false` while enabled. Adding a Lix package does
not transfer daemon ownership. The host-scoped migration must stop importing or
enabling that module for the migrated Mac and restore `nix.enable = true`.
Keep the input/module available to Seqeratop during a staged rollout.

## Gates for a future Mac migration

These requirements preserve findings from the
[repo Darwin audit](https://ampcode.com/artifacts/darwin-audit-and-lix-migration-19aa213b-01fd-44e4-bb8b-ed8a83ff1d67)
and [MacTraitor-Pro live audit](https://ampcode.com/artifacts/mac-darwin-live-audit-906118e4-9133-46bb-84e0-e4ac4ace38d4).
The artifacts require their existing Amp access. The operational caveats are
recorded below so repository readers do not need access to use this document.
They apply when returning to either Lix or upstream Nix under nix-darwin.

1. Preserve `/nix`, its database, profiles, encrypted APFS volume and recovery
   roots. Do not run either uninstaller or delete the volume. Root both runtime
   closures, keep an independent working CLI and local administrator access,
   save configurations/plists/profile manifests privately, and make a consistent
   SQLite backup with the schema file after quiescing writers. Freeze deleting
   GC during handover. The live schema was 10, matching the audited Lix releases;
   a matching number alone does not prove full compatibility or safe rollback.
2. Transfer daemon, socket and configuration ownership together. Stop Nixd and
   its worker before starting `org.nixos.nix-daemon`. Retire Determinate's repair
   hook and any restart/updater machinery that could restore the old runtime.
   Inventory actual plists rather than guessing labels. The live daemon socket
   was a link to `/var/run/nix-daemon.socket`; reconcile that with the new direct
   socket arrangement only after the old owner stops. Never run two daemon
   families against the store.
3. Replace the current Determinate-only pre-activation version check and its
   `org.nixos.nix-daemon` bootout behavior in the same candidate. They would
   otherwise reject or stop the replacement. Transfer settings, registry, caches,
   keys, access policy and parallelism to `nix.*`. Keep one GC/optimise owner and
   preserve the current retention policy. Retain state version and account IDs;
   test restored build-user behavior rather than mixing in sandbox hardening.
4. Resolve `/etc` adoption before the maintenance window. The
   [locked nix-darwin check](https://github.com/nix-darwin/nix-darwin/blob/d5bd9cd77aea4c0a8f49e7fd85545671a208ed15/modules/nix/default.nix#L881-L924)
   rejects a non-placeholder `nix.custom.conf`; it does not import its settings.
   Migrate wanted settings first, then preserve the old custom file and
   installer-owned `nix.conf` under unique backup names. Existing
   `.before-nix-darwin` backups must not be overwritten.
5. Prove encrypted APFS boot mounting without Nixd before retiring Nixd init.
   The live Mac had both an Apple-tool-only `org.nixos.darwin-store` helper and
   `systems.determinate.nix-store`. Their successful one-shot exits do not prove
   independent cold boot. Establish one verified mount/unlock owner, preserve
   Keychain unlock material, `/etc/fstab` and `/etc/synthetic.conf`, and keep boot
   prerequisites available before `/nix` mounts. Require a real reboot test.
6. Replace CA handling deliberately. Nixd exports Keychain certificates to
   `/etc/nix/macos-keychain.crt`. A stale exported file is not continued Keychain
   integration, and nixpkgs' public CA bundle does not add corporate trust.
   Seqeratop needs an approved replacement bundle/export and refresh policy,
   tested against real corporate TLS, private inputs and caches. Do not disable
   certificate verification to make migration succeed.
7. Check PATH and the global profile. On the audited Mac,
   `/nix/var/nix/profiles/default/bin` shadowed system Nix, and the profile held
   both Determinate and `nss-cacert`. Preserve its certificate dependency; do not
   replace the entire profile with Lix. After securing recovery, retire only the
   old runtime entry or fix managed PATH ordering. Check fresh user/root shells,
   launchd jobs, `type -a nix` and legacy `nix-*` helpers. A new CLI version is
   not evidence that the new daemon serves requests.
8. Validate the exact candidate with affected repo checks, Darwin validation and
   a pre-activation build through the supported `hey` workflow. Require the
   intended daemon executable, exactly one daemon owner, effective config and
   registry checks, a fresh uncached daemon build with checked output, real repo
   workloads and linked tools. Repeat after reboot. MacTraitor-Pro must pass
   before Seqeratop, which also needs workplace/MDM and CA acceptance. No builder
   experiment belongs in the handover.

There is no verified one-command store-preserving Determinate.pkg-to-Lix
procedure in these audits. A generic Lix upgrade script does not transfer the
repair hook, APFS mount, socket or CA responsibilities. Runtime recovery must
restore those owners as well as the package. A Darwin generation rollback alone
cannot do that, and restoring an old database after new store writes needs a
coordinated recovery plan. Keep the existing
[Determinate installation/recovery runbook](runbooks/determinate-darwin.md)
for the current arrangement; it is not a reverse migration script.

NixOS does not need the macOS installer/APFS/Keychain handover. A future Lix
trial there still needs release/feature compatibility checks, a known-good boot
generation and representative daemon builds before and after restart/reboot.
Do not treat system-generation rollback as permission to ignore store database
compatibility, or apply the Darwin `nix.enable = false` rule to Linux.
Determinate has a separate NixOS module; this repo does not import it, and its
Linux integration must be reviewed on its own terms if ever proposed.

## Sources

External guidance checked 2026-11-22, alongside the locked sources linked above:

- [nix-darwin README](https://github.com/nix-darwin/nix-darwin#prerequisites)
  and [option manual](https://nix-darwin.github.io/nix-darwin/manual/).
- [Lix stable switching guidance](https://lix.systems/add-to-config/),
  [project goals and technical differences](https://lix.systems/about/), and
  [governance](https://lix.systems/governance/).
- [Determinate features and configuration](https://docs.determinate.systems/determinate-nix/),
  [Nixd certificate management and initialization](https://docs.determinate.systems/determinate-nix/determinate-nixd/),
  and [Native Linux Builder requirements](https://docs.determinate.systems/determinate-nix/native-linux-builder/).
