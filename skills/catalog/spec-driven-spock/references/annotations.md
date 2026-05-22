# Spock 2.x metadata annotations — cheat sheet

All annotations live in `spock.lang.*`. Import only what the spec uses.

## `@Title`

**Class-level only.** A one-sentence summary surfaced in Spock HTML
reports and IDE plugins. The value should read as a complete sentence
that could replace the class name in a sentence like "this spec asserts
that…".

```groovy
@Title("Lineage Validate — semantic equivalence check")
class LineageValidateSpec extends Specification { ... }
```

Avoid restating the class name (`"LineageValidateSpec"` is useless).
Avoid trailing punctuation.

## `@Narrative`

**Class-level only.** A multi-line backstory. Use the BDD convention:

```groovy
@Narrative('''
As a pipeline author wiring `nextflow lineage validate` into CI,
I want fast pass/fail with structured output,
so that I can gate on data-layer drift without writing a custom parser.
''')
```

Two or three short paragraphs is plenty. The audience is a reader who
opens the spec cold and needs to understand _why_ it exists — not what
each method does (the methods' names already do that).

## `@Subject`

**Class or field.** Marks the class under test. Spock uses this in
reports; humans use it as a fast pointer to "the thing this spec
exercises".

Class-level form:

```groovy
@Subject(LinNormalizer)
class LinNormalizerTest extends Specification { ... }
```

Field-level form (when the SUT is one of several injected dependencies):

```groovy
@Subject LinNormalizer normalizer = new LinNormalizer()
```

If a spec covers multiple subjects, name the primary one. If there's
genuinely no single subject, omit `@Subject` rather than lying.

## `@See`

**Class or method.** Accepts a single `String` or a `String[]`. Renders
as a clickable link in Spock reports.

```groovy
@See("https://spockframework.org/spec")
class SeeDocSpec extends Specification {

    @See([
        "https://en.wikipedia.org/wiki/Levenshtein_distance",
        "https://www.levenshtein.net/"
    ])
    def "Even more information is available on the feature"() {
        expect: true
    }

    @See("https://www.levenshtein.de/")
    @See([
        "https://en.wikipedia.org/wiki/Levenshtein_distance",
        "https://www.levenshtein.net/"
    ])
    def "And even more information is available on the feature"() { ... }
}
```

Multiple `@See` annotations stack on the same target — Spock 2.4 makes
the annotation `@Repeatable`. Prefer one URL per `@See` for readability
once you have more than two.

**Annotation-constant restriction.** Annotation values must be
compile-time constants. Java/Groovy reject `STATIC + "#section"`
concatenation inside `@See(...)`. Always inline the full URL literal.

## `@Issue`

**Class or method.** Same shape as `@See` but semantically for tracking
references — Jira tickets, GitHub issues, fogbugz numbers. Spock reports
render `@Issue` distinctly from `@See` (often as a "bug" badge), which
helps reviewers triage failing tests.

```groovy
@Issue("https://github.com/<org>/<repo>/issues/1234")
def 'no longer crashes when input is empty'() { ... }
```

If a test fixes a regression, link to _both_ the bug and the design
note: `@Issue(...)` for the bug, `@See(...)` for the ADR / RFC. Don't
double-link the same URL.

## `@PendingFeature`

**Method-level only.** Marker for "this behaviour is designed but not
yet implemented". Spock runs the test, then:

- If the test **fails**, marks it skipped (build stays green).
- If the test **passes**, marks it as _unexpected pass_ and **fails the build**.

That asymmetry is the whole point. A pending feature serves as an
executable design contract that fires when the implementation finally
lands.

Idiomatic stub body:

```groovy
@PendingFeature
@See("https://github.com/.../adr/foo.md#dN")
def 'feature description in present tense'() {
    expect: false
}
```

Why `expect: false`?

- Spock requires at least one block (`expect`, `then`, `when`+`then`) per feature method.
- `expect: false` is the shortest body that fails for the right reason ("this isn't implemented yet").
- When a dev replaces the body with real assertions, the test starts passing — Spock's unexpected-pass fires — they get the signal to remove the `@PendingFeature` annotation.

**Don't use `@PendingFeature` for flaky tests.** Use `@Ignore("reason")`
for that. `@PendingFeature` is a design contract, not a quarantine.

### `@PendingFeatureIf`

Conditional variant. The test pends _only_ when a predicate matches:

```groovy
@PendingFeatureIf({ os.windows })
def 'parses POSIX paths'() { ... }
```

The closure runs against a `SpockExt` context that exposes `os`,
`jvm`, `env`, etc. Use this for behaviour that's pending on one
platform / configuration only.

## `@Unroll`

**Class or method.** For data-driven specs (`where:` block), Spock by
default reports them as a single test. `@Unroll` reports each row as a
separately-named test, with placeholders interpolated from the row:

```groovy
@Unroll
def 'exit code is #code when #scenario'() {
    expect: validate(scenario) == code
    where:
    code | scenario
    0    | 'equivalent'
    1    | 'differs'
    2    | 'load error'
}
```

Report names: `exit code is 0 when equivalent`, etc.

You can apply `@Unroll` at the class level to make every data-driven
method in the spec unrolled by default. Spock 2.x lets you opt out
per-method with `@Rollup`.

Placeholders accept any `where:` column name. For nested fields use
GString-like syntax: `#user.name`.

## `@Snapshot`

**Field-level (since Spock 2.4).** Injects a `Snapshotter` configured
for the spec.

```groovy
@Snapshot Snapshotter snapshotter

def 'renders report'() {
    expect:
    snapshotter.assertThat(report).matchesSnapshot()
}
```

Snapshot files live alongside the spec by default
(`MySpec-renders_report.txt`). Run with `-Dspock.snapshots.update=true`
to refresh.

Commit the snapshot files. A snapshot change is a contract change; the
PR diff should make that explicit.

For more complex flows (named snapshots, custom serialisation), see
the Spock 2.4 snapshot docs:
https://spockframework.org/spock/docs/2.4/all_in_one.html#_snapshot_testing

## Quick decision tree

- "I want a reader to understand the spec's purpose" → `@Title` + `@Narrative`
- "I want a reader to find what's being tested" → `@Subject`
- "I want a reader to find the design source" → `@See` (or `@Issue` for tickets)
- "I want a designed-but-unbuilt behaviour to fail CI when it ships" → `@PendingFeature`
- "I want a flag matrix / exit-code table to read as N tests" → `@Unroll`
- "I want the spec to assert against a serialised fixture" → `@Snapshot`
