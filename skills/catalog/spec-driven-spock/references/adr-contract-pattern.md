# Worked example — ADR-driven contract specs

This pattern ships an ADR alongside an **executable contract**: every
numbered decision in the ADR becomes a `@PendingFeature` spec that runs
but stays skipped until the implementation fills it in.

Mechanic:

1. ADR enumerates decisions D1, D2, … Dn.
2. Contract spec carries one `@PendingFeature` method per decision, each
   `@See`-linked to the decision's anchor in the ADR.
3. The spec class declares the _audience_ via `@Title` / `@Narrative`.
4. Stub bodies are `expect: false`, so the test always fails → Spock
   marks pending features skipped → CI green.
5. As implementation lands a decision, a developer replaces the stub
   body with a real Given/When/Then and removes `@PendingFeature`. If
   they forget, Spock fires _unexpected pass_ and CI fails — the
   safeguard.

## Real-world example

[ADR 20260521-lineage-validate.md](https://github.com/nextflow-io/nextflow/blob/master/adr/20260521-lineage-validate.md)
defines 18 decisions for a `nextflow lineage validate` CLI command.
Forty-six pending-feature stubs cover the contract, split across four
files by audience:

| File                             | Decisions                          | Audience                                |
| -------------------------------- | ---------------------------------- | --------------------------------------- |
| `LineageValidateCliFlagsSpec`    | D1, D6, D7, D8, D17 (flag only)    | pipeline authors wiring CI              |
| `LineageValidateEquivalenceSpec` | D2, D3, D5, D9, D14, D16, D18      | reviewers debating "what is equivalent" |
| `LineageValidateBaselineSpec`    | D4, D10, D12                       | plugin authors writing a resolver       |
| `LineageValidateReportingSpec`   | D11, D13, D15, D17 (informational) | tooling integrators consuming the diff  |

The split is purely organisational. The runtime implementation behind
all four specs is a single `LineageValidator` core; the audience split
keeps each file scannable (~100-150 lines each instead of 350).

## Why split

A single-file contract works fine up to ~250 lines. Beyond that:

- Readers get lost.
- Diffs become noisy.
- Different reviewers care about different sections — splitting reduces
  the surface they have to skim.

But avoid splitting too aggressively. One file per ADR decision creates
40+ tiny files for a medium ADR, which buries the contract. Split when
audiences diverge, not before.

## Split heuristic

Look at the ADR's decision blocks and group them by **who would push
back**:

| Group                                         | Reader                          |
| --------------------------------------------- | ------------------------------- |
| CLI flags, environment, config                | the engineer wiring CI          |
| Equivalence rules ("what counts as the same") | the reviewer debating semantics |
| Baseline / resolver / schema                  | the plugin author               |
| Diff shape / categories                       | the tooling integrator          |

If two groups have the same reader, merge them. If one group has zero
identifiable reader, it might not belong in the contract.

## Naming convention

`<DomainName>ContractSpec` — `*ContractSpec` is the suffix that signals
"this is the design contract, not the implementation test." Real-test
specs use `*Test` or `*Spec` without the `Contract` prefix.

When split: `<DomainName><Concern>Spec` — e.g.,
`LineageValidateCliFlagsSpec`. The shared `<DomainName>` prefix groups
the files in the file tree.

## Class-level scaffold for each contract spec

```groovy
@Title("<DomainName> — <concern> contract")
@Narrative('''
Audience: <who reads this>. Pins <decisions D-N covered>. Every method
here is a pin against the corresponding decision in
adr/YYYYMMDD-<title>.md; replacing a stub with a real spec is how an
ADR decision graduates from "documented" to "shipped".
''')
@See([
    "https://github.com/<org>/<repo>/blob/master/adr/YYYYMMDD-<title>.md",
    "https://github.com/<org>/<repo>/pull/<adr-pr>",
    "https://spockframework.org/spock/docs/2.4/all_in_one.html#_pendingfeature"
])
class <DomainName><Concern>Spec extends Specification { ... }
```

## Method-level pattern

```groovy
@PendingFeature
@See("https://github.com/<org>/<repo>/blob/master/adr/YYYYMMDD-<title>.md#d7--<slug>")
def 'CI=true switches default output mode to --json'() {
    expect: false
}
```

Section delimiters help readers navigate within a file:

```groovy
// ───── D7 — Auto-detect CI / agent environments ──────────────────────

@PendingFeature
@See("...#d7--...")
def 'CI=true switches default output mode to --json'() { expect: false }

@PendingFeature
@See("...#d7--...")
def 'GITHUB_ACTIONS=true emits ::error:: annotations'() { expect: false }
```

The `// ─── ────` comment style is purely visual; nothing in Spock
cares about it. Use the same delimiter style as the ADR's section
headers for symmetry.

## `@Unroll` for table-pinned contracts

When an ADR pins a matrix (exit codes, format flags, status columns),
one `@Unroll` spec replaces N copy-paste methods:

```groovy
@Unroll
@PendingFeature
@See("https://github.com/.../adr/foo.md#d6--exit-codes")
def 'exit code is #code when #scenario'() {
    expect: false
    where:
    code | scenario
    0    | 'runs are semantically equivalent'
    1    | 'runs differ in any failing category'
    2    | 'load failure, schema mismatch, or resolver error'
}
```

Spock reports each row separately. If you later need to give one row
its own narrative or extra `@See`, promote that row into its own
method.

## Graduation workflow

When an ADR decision ships:

1. The developer implementing the decision finds the matching stub by
   searching the contract spec(s) for the ADR section anchor (e.g.,
   `#d7--auto-detect-ci`).
2. Replaces `expect: false` with a real Given/When/Then.
3. Removes `@PendingFeature`.
4. Runs the suite. If Spock reports an unexpected pass, the
   `@PendingFeature` was not removed and CI catches it.
5. If new edge cases emerge, adds them as additional methods (still
   `@See`-linked to the decision); doesn't expand the original stub
   into a 50-line spec.

## Bookkeeping

- Keep the contract spec(s) and the ADR in the same PR when first
  shipped. Otherwise the contract drifts from the design.
- When an ADR decision is rescinded or amended, also amend or remove
  the matching stub in the same commit.
- Don't move `@PendingFeature` stubs out into "future work" lists —
  the whole point is that the contract is in the build, not the
  documentation.

## Anti-patterns

- **Empty `@Narrative`.** If a reader can't tell the spec's audience
  from one paragraph, the audience probably wasn't clear at design
  time either; resolve that first.
- **`@See` pointing at the local file system.** Spock reports render
  these as plain text; readers can't click through. Always use a
  durable URL (merged file path on master, PR number, issue link).
- **`@PendingFeature` without `@See`.** A pending feature with no
  source-of-truth link is a TODO masquerading as a contract — it will
  rot.
- **One spec per ADR decision, in separate files.** The cardinality
  is wrong — small ADR / one file, big ADR / split by audience, never
  one file per decision.
- **Replacing a pending stub but keeping `@PendingFeature`** in the
  hope CI will tell you. CI _will_ tell you, but only after the build
  has fired the unexpected-pass — you can save the cycle by
  remembering. The point of the safeguard is to catch forgetfulness,
  not as a primary signal.
