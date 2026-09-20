---
purpose: Record repository Oxlint paths for anti-slop and opt-in Jev rules.
applies_to: JavaScript and TypeScript lint, English Jev rules, TypeSafe keys.
entrypoint: Default hook is anti-slop. Jev is nix run .#oxlint-plugin-jev.
verification: python3 -m unittest tests.test_oxlint_jev tests.test_package_policy
update_when: Oxlint pins, plugin packaging, or Jev secret wiring change.
---

# Oxlint

This checkout has two Oxlint paths. They do not share a binary or plugin API.

## Anti-slop (default)

Pre-commit and `hey check` run Oxlint **1.78.0** from `nixpkgs-anti-slop` with
`packages/anti-slop` (`@oxlint/plugins` 1.78.0). That hook stays the repository
TypeScript-shape lint. Do not load Jev into it.

## Jev (opt-in)

[oxlint-plugin-jev](https://github.com/wobsoriano/oxlint-plugin-jev) 0.1.1
needs Oxlint **>= 1.83.0**. It is packaged under `packages/oxlint-plugin-jev`
with a matching `oxlint` 1.83.0 CLI in the same npm lock. A coordinated bump
of anti-slop plus Oxlint is a separate change and needs its own proof.

```sh
nix run .#oxlint-plugin-jev -- path/to/file.ts
nix shell .#oxlint-plugin-jev --command oxlint-jev path/to/dir
```

The wrapper uses `--disable-nested-config` and the store config at
`$out/share/oxlint-jev.json`. It is not a pre-commit hook.

### English rules

Edit `packages/oxlint-plugin-jev/rules.json`. Each item is one `jev/ask` rule:

| Field | Meaning |
| --- | --- |
| `id` | Shown in the diagnostic. Unique in the list. |
| `target` | `function`, `call`, `jsx`, or `file`. |
| `question` | Yes/no. Yes means report. |
| `cutoff` | 0 to 1. Report at or above Jev's yes-probability. |

Starter rules: no PII in logs, no secrets in logs, and names that match
behavior. After you edit the list, rebuild the package. The plugin schema
rejects unknown fields at startup.

Keep `jev/ask` out of any config the editor loads. Each keystroke inside a
match is a paid TypeSafe request.

### Secret

Jev reads `TYPESAFE_API_KEY` from the process environment. Get a key at
https://console.typesafe.ai. Do not put the value in `flake.nix`, Git, or
Nix output.

Local options, in the usual secret order for this repo:

1. **direnv.** Add `export TYPESAFE_API_KEY=...` to gitignored `.envrc.local`.
   Root `.envrc` already sources that file.
2. **1Password.** `op run -- oxlint-jev ...` or
   `export TYPESAFE_API_KEY="$(op read 'op://Vault/TypeSafe/credential')"`.
3. **agenix / opnix file.** Export `TYPESAFE_API_KEY_FILE` to the decrypted
   path. The wrapper copies that file into `TYPESAFE_API_KEY` for the child
   Oxlint process. Do not pass the value on the command line.

CI and any other `CI=1` run use the plugin default `ci: "skip"`. A missing
key warns once and reports nothing. Set `ci` to `"fail"` in the generated
config only if you want a missing key to fail the run.

### Version pins

| Path | Oxlint | Plugin |
| --- | --- | --- |
| Default hook | 1.78.0 (`nixpkgs-anti-slop`) | anti-slop / `@oxlint/plugins` 1.78.0 |
| `oxlint-jev` | 1.83.0 (npm lock) | `oxlint-plugin-jev` 0.1.1 |

Refresh Jev by editing `packages/oxlint-plugin-jev/package.json`, running
`npm install` there, and keeping the two asserts in `default.nix` in sync.
