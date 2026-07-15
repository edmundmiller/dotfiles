---
name: ast-grep
description: >
  Structural code search, refactoring, and repository lint-rule setup with
  ast-grep. Use when searching by syntax shape, writing or testing ast-grep
  rules, configuring sgconfig.yml, enforcing coding standards, selecting rule
  severity, or adding ast-grep to project checks and CI.
license: MIT
metadata:
  version: "2.0.1"
  author: "Edmund Miller"
---

# ast-grep

Use ast-grep for syntax-aware search, rewriting, and tested structural coding standards. Keep formatting, type checking, path-only policy, cross-file value equality, and runtime behavior with their owning tools.

Use `code-search` when deciding between ast-grep and text search. After selecting ast-grep, use this skill as the source of truth for command syntax, patterns, rewrites, and repository standards.

## Choose the right mode

| Need                                     | Mode                                       |
| ---------------------------------------- | ------------------------------------------ |
| Find one syntax shape                    | `ast-grep run --pattern ... --lang ...`    |
| Preview or apply one rule file           | `ast-grep scan --rule rule.yml`            |
| Enforce repository standards             | `sgconfig.yml` + rule and test directories |
| Search literal text, comments, or docs   | grep, not ast-grep                         |
| Follow definitions, references, or types | language server, not ast-grep              |

Reuse an existing compiler or linter rule before adding parallel policy.

## Search and refactor

Start with the smallest valid AST pattern:

```bash
ast-grep run --lang typescript --pattern 'console.log($$$ARGS)' src
ast-grep run --lang python --pattern 'print($$$ARGS)' .
```

Use metavariables deliberately:

| Syntax       | Meaning                               |
| ------------ | ------------------------------------- |
| `$VAR`       | one named AST node                    |
| `$$VAR`      | one named or anonymous node           |
| `$$$ARGS`    | zero or more nodes                    |
| `$_` / `$$$` | non-capturing single/sequence matches |

Quote patterns with single quotes so the shell does not expand `$`.

Inspect how a plausible query pattern is parsed when it misses:

```bash
ast-grep run --lang typescript --pattern 'console.log($$$ARGS)' --debug-query=ast src/example.ts
ast-grep run --lang typescript --pattern 'console.log($$$ARGS)' --debug-query=pattern src/example.ts
```

`--debug-query=ast` prints the query pattern's AST, not the source file's AST. Use the ast-grep Playground or language-specific tree-sitter tooling when the source tree itself must be inspected.

For a rewrite, preview before applying:

```yaml
id: replace-console-log
language: TypeScript
rule:
  pattern: console.log($$$ARGS)
fix: logger.info($$$ARGS)
```

```bash
ast-grep scan --rule replace-console-log.yml src
ast-grep scan --rule replace-console-log.yml --update-all src
```

Treat `fix` as textual substitution, not parsed output. Run the project formatter, type checker, and focused tests after applying a rewrite.

## Set up repository standards

1. Inspect repository languages, generated/vendor paths, existing linters, package manager, check runner, CI, and local agent instructions.
2. Install `ast-grep` reproducibly through the repository toolchain. Prefer the `ast-grep` executable over the `sg` alias. Pin a version when parser or snapshot stability matters.
3. Confirm every required parser with a literal smoke query. Treat an unsupported-language error as a packaging problem, not a reason to replace structural policy with text search.
4. Create:

   ```text
   sgconfig.yml
   ast-grep/
   ├── rules/
   │   └── no-console-log.yml
   └── rule-tests/
       └── no-console-log-test.yml
   ```

5. Configure project discovery:

   ```yaml
   ruleDirs:
     - ast-grep/rules
   testConfigs:
     - testDir: ast-grep/rule-tests
   ```

6. Verify the selected project root and config:

   ```bash
   ast-grep scan --inspect summary
   ```

`scan` requires `sgconfig.yml`. Project discovery starts in the working directory and walks upward; use `--config path/to/sgconfig.yml` when invoking from elsewhere.

## Author lint rules

Start from an observed violation and the smallest rule that separates it from valid code.

```yaml
id: no-console-log
language: TypeScript
severity: warning
files:
  - src/**/*.ts
  - src/**/*.tsx
ignores:
  - src/generated/**
message: Use the project logger instead of console.log.
note: Replace console.log with the logger appropriate to this module.
rule:
  pattern: console.log($$$ARGS)
```

Require:

- a stable kebab-case `id`
- the exact parser `language`
- a concise, actionable `message`
- a `note` when remediation is not obvious
- narrow `files` or `ignores` where the contract is not global
- the least complex rule object that expresses the invariant

Keep `files` and `ignores` relative to the `sgconfig.yml` directory. Never prefix their globs with `./`.

Add `constraints`, relational rules, `labels`, `transform`, or `fix` only when tests prove the simpler rule insufficient. Apply `constraints` only to single metavariables; they filter after the main rule matches and cannot repair conflicting patterns inside `not`.

For detailed rule composition, read `references/rule-reference.md`.

## Test every rule

Create a test file whose `id` exactly matches the rule:

```yaml
id: no-console-log
valid:
  - logger.info('ready')
  - console.error('fatal')
invalid:
  - console.log('ready')
  - console.log(message, context)
```

Cover:

- plausible `valid` code that must not report, preventing noisy matches
- every prohibited `invalid` form the rule claims to detect, preventing missing matches
- boundaries such as nesting, alternate syntax, and structural exclusions

`valid` and `invalid` cases are source snippets and do not exercise `files` or `ignores`. Verify path globs with a temporary project scan or a focused real-tree smoke test containing included and excluded files.

Run detection tests while iterating:

```bash
ast-grep test --skip-snapshot-tests
```

Commit snapshots when diagnostic spans, labels, or messages are part of the contract:

```bash
ast-grep test --update-all
ast-grep test
```

Keep `--skip-snapshot-tests` in the permanent check only when detection is the complete contract and diagnostic layout is intentionally unstable. Never use interactive snapshot updates in CI.

For a rule regression, add a failing `valid` or `invalid` case first, confirm the expected noisy or missing failure, then fix the rule.

## Choose severity

| Severity  | Policy                                    | Scan behavior              |
| --------- | ----------------------------------------- | -------------------------- |
| `error`   | Established invariant that blocks changes | Non-zero exit when matched |
| `warning` | Actionable standard during adoption       | Reports a warning          |
| `info`    | Migration or informational finding        | Reports informationally    |
| `hint`    | Low-priority guidance; default            | Reports a hint             |
| `off`     | Temporarily disabled configuration        | Does not run               |

Promote a rule to `error` only after tests prove low false-positive risk, remediation is actionable, and the baseline is clean or narrowly scoped. Use CLI overrides for staged rollout or CI policy:

```bash
ast-grep scan --error=no-console-log
ast-grep scan --off=no-console-log
ast-grep scan --inspect entity
```

## Control suppressions

Prefer narrow, rule-specific suppression comments with a nearby reason:

```typescript
// Third-party bootstrap requires direct console output.
console.log(message); // ast-grep-ignore: no-console-log
```

Avoid bare `ast-grep-ignore`, which suppresses every diagnostic. After verifying version support and cleaning the baseline, enforce explicit IDs and stale-suppression cleanup:

```bash
ast-grep scan --error=no-suppress-all --error=unused-suppression
```

## Integrate project checks

Run rule tests before scanning the real tree:

```bash
ast-grep test --skip-snapshot-tests
ast-grep scan
```

Add both commands to the existing local check runner and CI rather than creating a parallel validation path. Keep local and CI config, binary version, working directory, and severity overrides identical.

Prove the complete setup:

1. Run the expected binary version from the repository toolchain.
2. Load every configured parser with a literal smoke query.
3. Pass all rule tests.
4. Scan the repository with the intended severity behavior.
5. Exercise both commands through the normal project check.
6. Update the repository's agent/router documentation so AST rules route to ast-grep and non-AST policy remains with its owning tool.

## Avoid failure modes

- Do not create a lint rule without at least one valid and one invalid case.
- Do not use string search disguised as an AST pattern.
- Do not assume a parser is bundled; smoke-test it.
- Do not weaken a rule merely to make a dirty baseline pass; fix, scope, or stage rollout explicitly.
- Do not add broad suppressions to silence false positives; improve the rule and tests.
- Do not duplicate ESLint, Ruff, Clippy, compiler, formatter, or runtime checks.
- Do not rely on a narrowed scan as the only CI gate if the standard is repository-wide.

## Official references

- [Project configuration](https://astgrep.com/guide/project/project-config)
- [Lint rules](https://astgrep.com/guide/project/lint-rule)
- [Rule tests](https://astgrep.com/guide/test-rule)
- [Severity and suppressions](https://astgrep.com/guide/project/severity)
