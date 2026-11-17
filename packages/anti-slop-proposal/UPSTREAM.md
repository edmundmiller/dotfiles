# Anti-slop source and policy

The immutable `anti-slop-incoming` flake input supplies the canonical source,
tests and licenses. This package does not maintain a second source copy.
Edmund approved staged activation. The ordinary hook retains the original
`anti-slop` input, package, rule severities and Oxlint 1.78.0.

- Source: https://github.com/K-Mistele/anti-slop
- Incoming revision: b7c1619b4d51b4815e89ba3700a975a6ec54b8c3
- Recoverable previous source: https://github.com/dmmulroy/anti-slop at
  446268e5d15baa968eaec669ff65358d36ae6259, recorded in the previous flake.lock.
- Local baseline: dotfiles e84aab124c228133978edf69d4279dcb9d5f5f3a.
- Procedure: incoming README and
  `skills/install-anti-slop/references/update.md`.

There were no source patches or local-only AST rules at the previous pin. The
reviewed proposal adopts the incoming source and retains all upstream tests. The
old `no-conditional-empty-object-spread` becomes the broader
`no-conditional-spread`, still at error. Its old rejected forms remain rejected.
Other existing rule names retain their error severity, with upstream alias,
parameter, assertion-comment and mock detection improvements.

`oxlint.json` owns the explicit proposal configuration. It retains the five agent-directory
ignores, adds the vendored Jev build ignore, enables every incoming core rule at
error and Fowler AST recommendations at warn, and explicitly keeps
`message-chains` off. Effect AST rules apply only to `packages/callstack-diff`,
whose actual dependency is Effect 4.0.0-beta.105. Context.Service, Layer.effect,
Effect.fn/withSpan, tagged constructors and tagged catch handlers were checked
against that installed version. No Effect dependency was upgraded. The existing
package-local Effect tsgo diagnostics remain in place.

The second ordinary hook runs `anti-slop-additions`. It activates
`no-reduce-accumulator-copy`, `no-reprovide-ambient-service`, their native
`no-accumulating-spread` companion, all seven Fowler advisories and 12 Effect
rules. `no-manual-tag-comparison` and `prefer-effect-match` remain proposed.
All conflicting core behavior stays in the full proposal. This staging is not
a permanent exemption or full acceptance.

The additive scan retains the previous source implementation under `anti-slop`
and its exact 15-rule policy, shared through `packages/anti-slop/rules.json`.
New core rules use the separate `anti-slop-additions` registration. This keeps
the existing suppression counts valid without skipping validation or pruning
them. The previous source is copied unmodified from its locked input, with its
license, and resolves the additive package's matching CLI/API 1.86.0 pair.
The original 1.78.0 hook still runs independently.

Oxlint and `@oxlint/plugins` are both exactly 1.86.0, the incoming tested pair.
Node 22.18 or newer is required to load TypeScript. Packaging uses Node 22 and
copies the upstream MIT license plus the complete `src/vendor/eslint-stylistic`
license and provenance. Ordinary lint loads only AST entry points, never Jev.

The separate `packages/oxlint-plugin-jev` package retains its three local
questions, targets, error severities and cutoffs of 0.8, 0.8 and 0.6. Its exact
fork build provenance lives beside the build. Semantic presets require a second
explicit `--presets` opt-in; diff review is another executable. None is a hook,
editor default, or CI gate. See `docs/agents/oxlint.md` for disclosure boundaries
and verification commands. Full activation remains deferred because the proposal
exposes thousands of source findings and suppression incompatibilities. Existing
suppressions are unchanged.
