---
purpose: Route old Homebrew activation advice to the supported Darwin rebuild workflow.
applies_to: Homebrew failures during MacTraitor-Pro or Seqeratop activation.
entrypoint: Use hey re and inspect its failure output.
verification: Follow the rebuild failure runbook without suppressing activation errors.
update_when: The supported Darwin activation or recovery workflow changes.
---

# Homebrew activation

Both Mac hosts configure nix-homebrew. Use `hey re` for guarded Darwin
activation and the [rebuild failure runbook](runbooks/rebuild-failure.md) when it
fails. [Determinate Darwin guidance](runbooks/determinate-darwin.md) covers
the managed Nix installation.

The old two-step workaround is retired. Do not ignore activation failures or
look for the removed manual Homebrew activation helper. A completed build
does not mean activation succeeded.
