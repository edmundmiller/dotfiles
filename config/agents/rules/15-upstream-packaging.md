---
purpose: Package upstream CLI tools by pinning source and dependency hashes.
---

# Upstream Packaging

- Put new packages in `packages/<name>.nix` so they auto-discover into `pkgs.my`.
- Read the upstream manifest/README, pin source + dependency hashes, then rebuild once to capture the real hash.
- Verify with `nix build .#<name>` and a smoke test of the binary.
