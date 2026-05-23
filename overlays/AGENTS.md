# Overlay Notes

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

- This repo's `mapModules ./overlays import` supports either `overlays/foo.nix` or `overlays/foo/default.nix`. Use a directory overlay when the override needs supporting files such as a lockfile, patch, or generated data.
- For `buildNpmPackage` overrides that change `src` and `package-lock.json`, update both `npmDepsHash` and `npmDeps`. Otherwise `overrideAttrs` may keep the upstream fixed-output npm deps derivation even though the new source has a different lockfile.
- If a source tarball includes `npm-shrinkwrap.json` but the override uses a repo-local `package-lock.json`, remove the shrinkwrap in the prepared source so npm uses the intended lockfile.
- Avoid adding temporary package copies under `packages/` just to override a flake input package. Keep the override and its support files local to `overlays/<name>/` unless the package is intended to become a first-class local package.
