---
purpose: Define override and patch-maintenance conventions for overlays.
applies_to: Changes under overlays/.
entrypoint: Use pkg-list, then read the target overlay and metadata.
verification: Run pkg-check for declared units and build the affected consumer.
update_when: Overlay structure, patch policy, or maintainer tooling changes.
---

# Overlay Notes

## Maintainer checks

- Run `pkg-list` to find units with optional adjacent `package-harness.json` metadata.
- Run `pkg-check <unit>` for read-only validation against a fresh upstream checkout.
- Use `hey` for deployment and host lifecycle, not package source validation.

References:

- <https://wiki.nixos.org/wiki/Overlays>
- <https://nixcademy.com/posts/mastering-nixpkgs-overlays-techniques-and-best-practice/>

- Prefer small overlays that modify the upstream derivation with `overrideAttrs` instead of re-declaring the whole package. Keep upstream install hooks, wrappers, metadata, and future fixes unless there is a specific reason to replace them.
- Use the normal overlay shape: `final: prev: { ... }`. Read dependencies from `final` when you want the post-overlay package set, and from `prev` when you want the upstream package being overridden.
- When overriding nested package sets, preserve the rest of the set:

  ```nix
  final: prev: {
    llm-agents = (prev.llm-agents or { }) // {
      pi = prev.llm-agents.pi.overrideAttrs (_old: {
        version = "...";
        src = ...;
      });
    };
  }
  ```

- This repo's `mapModules ./overlays import` supports either `overlays/foo.nix` or `overlays/foo/default.nix`. Prefer the `overlays/foo/default.nix` directory pattern when the overlay may need supporting files such as a lockfile, patch, generated data, or overlay-specific `AGENTS.md` guidance.
- For `buildNpmPackage` overrides that change `src` and `package-lock.json`, update both `npmDepsHash` and `npmDeps`. Otherwise `overrideAttrs` may keep the upstream fixed-output npm deps derivation even though the new source has a different lockfile.
- If a source tarball includes `npm-shrinkwrap.json` but the override uses a repo-local `package-lock.json`, remove the shrinkwrap in the prepared source so npm uses the intended lockfile.
- Avoid adding temporary package copies under `packages/` just to override a flake input package. Keep the override and its support files local to `overlays/<name>/` unless the package is intended to become a first-class local package.
- For `llm-agents` packages customized by this repo, overlay the nested package (for example `llm-agents.herdr` or `llm-agents.hunk`) and expose it to modules through `pkgs.my.<name>` via the flake package output. Avoid top-level `pkgs.<name>` aliases when they make the package origin ambiguous.
