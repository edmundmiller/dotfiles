---
name: spec-driven-spock
description: Use Spock 2.x metadata annotations (@Title, @Narrative, @Subject, @See, @Issue, @PendingFeature, @Unroll, @Snapshot) to make Spock specs act as executable design documentation — each spec tied to the ADR, ticket, or design doc it exercises. Use this skill whenever the user is writing or refactoring a Spock test, drafting an ADR that should ship with an executable contract, pinning design decisions to tests, splitting a large spec, marking unimplemented behaviour as pending, or wants the test suite to read as a self-documenting checklist of what the design promises — even if they do not explicitly mention Spock annotations.
---

# Spec-driven Spock

Spock has a small but underused set of metadata annotations that turn an
ordinary `Specification` into living design documentation:

| Annotation        | What it pins                                                             |
| ----------------- | ------------------------------------------------------------------------ |
| `@Title`          | One-line statement of what the spec is about (class)                     |
| `@Narrative`      | Multi-line "given / so that" backstory (class)                           |
| `@Subject`        | The class under test (class or field)                                    |
| `@See`            | URL(s) to external references — ADR, RFC, ticket, docs (class or method) |
| `@Issue`          | URL(s) to issues / tickets specifically (class or method)                |
| `@PendingFeature` | Marker for a not-yet-implemented behaviour — see below                   |
| `@Unroll`         | Per-row report names for data-driven specs                               |
| `@Snapshot`       | Inject a snapshot for snapshot-driven tests (Spock 2.4+)                 |

Spock renders these into HTML reports and surfaces them in IDE plugins,
which is why they pay rent. Stuffing the same information into Groovydoc
comments is invisible to the runtime.

For the per-annotation cheat sheet, read [references/annotations.md](references/annotations.md).

## When to reach for this skill

- A spec exists but a reader can't tell _why_ it's there. Add `@Title` + `@Narrative` + `@See`.
- A design decision (ADR, RFC, issue) lands and you want a test that fails if the decision is silently abandoned. Use the **executable contract** pattern.
- A class spec has grown past ~250 lines and now mixes audiences. Split by concern, give each new file its own `@Title`/`@Narrative`.
- A flag matrix or exit-code table is duplicated across N specs. Collapse with `@Unroll`.
- A behaviour is documented but not yet implemented. Pin it as `@PendingFeature` — Spock fails CI if the implementation lands without the marker being removed.

## Pattern 1 — Class-level scaffold

Every non-trivial spec should open with this header:

```groovy
@Title("One sentence — what is this spec asserting?")
@Narrative('''
Given/so-that prose. Two or three short paragraphs at most. Explain
the *audience* for this spec and what kind of change should make this
spec evolve.
''')
@See([
    "https://github.com/<org>/<repo>/blob/master/adr/YYYYMMDD-<title>.md",
    "https://github.com/<org>/<repo>/pull/<n>"
])
@Subject(ClassUnderTest)
class MyFeatureSpec extends Specification { ... }
```

The `@See` URLs render as links in Spock HTML reports and most IDE
plugins, so prefer stable URLs (a merged file path, a PR number, an
issue URL) over local paths.

## Pattern 2 — Per-method `@See`

Each feature method links to _its_ design source:

```groovy
@See("https://github.com/<org>/<repo>/blob/master/adr/2026-foo.md#d3--checksum-only")
def 'file outputs are compared by recorded checksum only'() {
    expect: ...
}
```

Use `@Issue` instead of `@See` when the link is specifically a bug or
ticket. Both accept a single String or a list of Strings, and both can
be repeated on the same target (Spock allows multiple `@See` annotations
on one feature).

Don't add a `@See` if the only reasonable link is the file the test is
already in — that's noise.

## Pattern 3 — The executable contract

When an ADR / RFC lands, ship an executable contract alongside it: every
numbered decision becomes a `@PendingFeature` stub that runs but stays
skipped until the implementation fills it in.

```groovy
@PendingFeature
@See("https://github.com/.../adr/foo.md#d7--auto-detect-ci")
def 'CI=true switches default output mode to --json'() {
    expect: false
}
```

Why `expect: false`?

- Spock's `@PendingFeature` skips a test that fails and **fails the build if it passes**.
- A body of `expect: false` always fails, so the stub stays skipped — green CI.
- When a dev implements the behaviour, they replace the body with a real assertion. If they forget to remove `@PendingFeature`, the now-passing test triggers Spock's unexpected-pass and CI goes red — that's the signal.
- A bare empty body won't compile (Spock requires at least one `expect`/`then`/`when` block).

This is the killer pattern for ADR-driven development. See
[references/adr-contract-pattern.md](references/adr-contract-pattern.md)
for a full worked example (a 4-file split of an 18-decision ADR), and
[assets/contract-spec-template.groovy](assets/contract-spec-template.groovy)
for a copy-pasteable skeleton.

## Pattern 4 — `@Unroll` for table-driven contracts

When the ADR / design pins a matrix (exit codes, format flags, status
columns), use one `@Unroll` spec instead of N copy-pasted methods:

```groovy
@Unroll
@PendingFeature
@See("https://.../adr/foo.md#d6--exit-codes")
def 'exit code is #code when #scenario'() {
    expect: false
    where:
    code | scenario
    0    | 'runs are semantically equivalent'
    1    | 'runs differ in any failing category'
    2    | 'load failure or schema mismatch'
}
```

Spock renders each row as a separately-named test (`exit code is 0 when runs are semantically equivalent`), so the HTML report reads as if you wrote three methods, but the source stays DRY.

## Pattern 5 — Splitting large contracts

If a contract spec passes ~250 lines or mixes audiences, split it.
Naming heuristic: one file per concern, one concern per audience.

For the lineage-validate ADR (18 decisions / 46 stubs), the split was:

| File                             | Decisions              | Audience            |
| -------------------------------- | ---------------------- | ------------------- |
| `LineageValidateCliFlagsSpec`    | flags, env, exit codes | pipeline authors    |
| `LineageValidateEquivalenceSpec` | equivalence rules      | reviewers           |
| `LineageValidateBaselineSpec`    | resolver SPI, schema   | plugin authors      |
| `LineageValidateReportingSpec`   | diff shape, categories | tooling integrators |

Each file gets its own `@Title` / `@Narrative` / class-level `@See`.
Each method keeps its own `@See` to the specific decision.

The split is _organisational_, not structural — the implementation
side stays a single shared core. Resist proliferating implementation
classes to match the spec split.

## Pattern 6 — `@Snapshot` for snapshot-driven specs

Spock 2.4 ships first-class snapshot support. Inject a `Snapshotter`
into the spec, point it at a directory, assert against it:

```groovy
@Snapshot
Snapshotter snapshotter

def 'renders the report as documented'() {
    expect:
    snapshotter.assertThat(actualReport).matchesSnapshot()
}
```

Set `spock.snapshots.update=true` (or run with `-Dspock.snapshots.update=true`) to refresh snapshots when the contract intentionally changes. Keep the snapshot files in version control next to the spec so a PR's diff shows the contract change explicitly.

## Pitfalls

- **Don't reference a `static final String` URL inside `@See` or `@Issue`.** Annotation values must be compile-time constants, and Java/Groovy reject `STATIC + "#section"` concatenation in annotation arguments. Inline the full literal URL.
- **Don't put `@Subject` on a field that isn't actually the SUT.** It's a documentation hint, not a wiring directive — claiming the wrong subject misleads readers.
- **Don't use `@PendingFeature` as a way to silence a flaky test.** The marker is for "designed but not yet implemented", not "we know it's broken." Use `@Ignore` (with a reason) for flake.
- **Don't lose the safeguard.** If you remove `@PendingFeature` from a stub _without_ replacing the body, you get a normal red build — that's fine. But never leave a `@PendingFeature` stub with a body that always passes (e.g., `expect: true`); Spock will fail the build immediately, which defeats the contract.
- **GitHub anchors are fragile.** Section headers change, anchor slugs drift. When the ADR is in the same repo, prefer linking to the file (no anchor) plus a `// D7 — ...` Groovy comment. Or use a tiny test that parses the ADR and verifies every `@See` anchor resolves.

## Workflow

When the user asks for help on a Spock spec:

1. **Read the spec.** Note what the test asserts and what design decision motivates it.
2. **Find the source of truth.** ADR, RFC, ticket, or PR. If there isn't one, ask whether one should exist — the spec may be the de facto source.
3. **Apply the class-level scaffold.** `@Title` + `@Narrative` + `@Subject` + class-level `@See` pointing at the source.
4. **Add per-method `@See`** only where the link is more specific than the class-level one.
5. **For ADR-driven work**, draft a `*ContractSpec` companion with `@PendingFeature` stubs for every decision; split by audience if it grows past ~250 lines.
6. **Run the suite** to confirm `@PendingFeature` stubs are skipped (not failing, not unexpectedly passing).

When inheriting a legacy `*Test` class that doesn't follow this style,
don't blanket-rewrite. Add annotations to the methods the current task
touches; leave the rest. Consistency across a codebase matters less than
making each spec individually self-explanatory.

## Further reading

- Spock 2.4 docs: https://spockframework.org/spock/docs/2.4/extensions.html
- Spock `@See`: https://spockframework.org/spock/docs/2.4/extensions.html#_see
- Spock `@PendingFeature`: https://spockframework.org/spock/docs/2.4/extensions.html#_pendingfeature
- Spock `@Snapshot`: https://spockframework.org/spock/docs/2.4/all_in_one.html#_snapshot_testing
- References:
  - [references/annotations.md](references/annotations.md) — per-annotation cheat sheet
  - [references/adr-contract-pattern.md](references/adr-contract-pattern.md) — worked example: ADR → 4-file contract spec split
  - [assets/contract-spec-template.groovy](assets/contract-spec-template.groovy) — copy-paste skeleton
