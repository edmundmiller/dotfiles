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
| Nascent manuscript prose and lightweight checks that do not hydrate DVC data                                    | Amp Orb             | Keep the Orb checkout data-light.                                                                                              |
| Nascent manuscript DVC data, full analyses, and data-derived outputs                                            | NUC                 | The local checkout was about 40 GB in August 2026, including about 39 GB of DVC cache, leaving unsafe headroom on a 60 GB Orb. |
| GPU inference or compute, Vulkan, Linux desktop, Wayland, Bluetooth, and audio integration                      | Meshify             | Verification requires Meshify's GPU, desktop session, or attached hardware.                                                    |
| Trace archives, databases of record, large durable datasets, and always-on services                             | NUC                 | Do not use a per-thread Orb as permanent storage or service infrastructure.                                                    |

## Hybrid work is expected

"Cannot finish in an Orb" does not mean "cannot start in an Orb." Keep source
editing, unit tests, and review in the Orb whenever possible. Transfer the
branch or diff to the required host only for the smallest final acceptance
step. Dotfiles and TaskNotes Native both follow this model.

Full genomics repositories follow the same split: use Orbs for workflow code,
manuscript text, and small fixtures; use the NUC or another data-capable compute
environment for full datasets and executions.

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
