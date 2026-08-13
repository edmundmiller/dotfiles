---
purpose: Define TTSR's role in an OMP-first thin agent harness.
applies_to: Shared agent rules, OMP rules, skills, hooks, and instruction routing.
entrypoint: Classify guidance with the placement test in this ADR before changing prompts.
verification: Run OMP TTSR list/test/scan, prompt-size checks, and scenario evaluations.
update_when: OMP rule semantics, harness scope, or migration evidence changes.
---

# ADR 0010: Use OMP TTSR as the corrective layer of a thin agent harness

## Status

Implemented in source for OMP; activation and other harnesses remain follow-up work

## Date

2026-08-12

## Context

The shared agent configuration currently concatenates every numbered file under
`config/agents/rules/` into the startup instructions for OMP, Codex, and Pi.
OMP then loads additional files from `config/omp/rules/`. This mixes several
different concerns in the always-on context:

- durable safety and authority boundaries;
- repository and subsystem routing;
- task-specific procedures;
- command and language conventions;
- corrections for known, detectable mistakes;
- writing preferences and general development advice.

These concerns do not have the same loading requirements. Procedural Git and jj
instructions are irrelevant to a question that never touches version control.
TypeScript constraints are irrelevant to a Markdown edit. Repeating them in
every turn consumes context and can oversteer a frontier model before the task
is understood.

The repository already has most of the needed progressive-disclosure surfaces:
nested `AGENTS.md` routers, task-triggered skills, canonical documentation,
deterministic checks, and OMP conditional rules. What it lacks is an explicit
placement policy that keeps guidance out of the startup prompt by default.

OMP's Time-Traveling Stream Rules (TTSR) fill one important gap. A TTSR rule is
registered with a regex `condition`, structural `astCondition`, and optional
stream `scope`. It remains out of the prompt until a matching model stream or
prospective edit is observed. Depending on its interrupt mode, OMP can abort
the stream and retry with the rule, defer the reminder, or prepend it to the
matching tool result. Injections persist in session state and survive
compaction. OMP exposes `ttsr list`, `ttsr test`, and `ttsr scan` so rules can be
inspected and tested without relying on prompt intuition.

The current installed runtime, `omp/17.2.11`, already registers the local
`commit-house-style`, `pr-house-style`, and `working-with-jj` rules as TTSR.
Bundled Go, Rust, and TypeScript corrections use the same mechanism. The choice
is therefore whether to make this existing mechanism the deliberate corrective
layer, not whether to introduce a new rule engine.

The original local rules were baseline material, not proof that every condition
was ready. Live CLI fixtures showed that `git commit -m test` triggered both
`commit-house-style` and `working-with-jj`, while the harmless search
`rg jj README.md` also triggered `working-with-jj`. The implementation retains
the meaningful commit overlap but anchors rules at shell command boundaries,
eliminating search-text false positives. Named fixtures now protect that
behavior.

## Evidence from the vault

Relevant notes in the Obsidian vault converge on the same direction:

- [Craft Context Dynamically, Not Statically](obsidian://open?vault=scientific-engagement&file=04_Resources/Podcasts/Snipd/Craft%20Context%20Dynamically%2C%20Not%20Statically.md)
  argues for concise context slices generated from the files relevant to the
  task instead of a large static root prompt.
- [Onboard Agents With Sharded Context](obsidian://open?vault=scientific-engagement&file=04_Resources/Podcasts/Snipd/Onboard%20Agents%20With%20Sharded%20Context.md)
  recommends a small repository entrypoint plus progressively disclosed
  subcontext.
- [Building pi in a World of Slop](obsidian://open?vault=scientific-engagement&file=04_Resources/Podcasts/Snipd/Building%20pi%20in%20a%20World%20of%20Slop%20%E2%80%94%20Mario%20Zechner.md)
  makes the case for a minimal, observable, extensible harness and notes that
  modern coding models already understand the basic agent role.
- [Inside Claude Code From the Engineers Who Built It](obsidian://open?vault=scientific-engagement&file=04_Resources/Podcasts/Snipd/Inside%20Claude%20Code%20From%20the%20Engineers%20Who%20Built%20It.md)
  describes removing prompt scaffolding as frontier models stop needing it and
  moving repeated enforceable mistakes into lint rules.
- [Repo Context Cleanup and Agent Docs Strategy](obsidian://open?vault=scientific-engagement&file=00_Inbox/Monologue/Repo%20Context%20Cleanup%20%26%20Agent%20Docs%20Strategy-2026-03-28.md)
  records the existing user decision to use nested `AGENTS.md` files for
  progressive disclosure.

These notes are design evidence and user preference, not controlled performance
measurements. The migration still needs scenario evaluations against the live
models and harness.

## Decision

Adopt a thin, layered instruction architecture and pilot it in OMP first.

```text
small shared core                     non-detectable universal invariants
        ↓
nested AGENTS.md                      repository and subsystem routing
        ↓
skills and canonical docs             task-triggered procedures and reference
        ↓
TTSR                                  dormant correction at a detectable mistake
        ↓
hooks, policy, lint, and tests         deterministic enforcement and proof
```

TTSR is the corrective layer. It is not the whole policy system.

### Placement test

Classify new or existing guidance in this order:

1. If correctness or safety can be enforced deterministically, use a policy,
   hook, type, lint, test, or guarded command. Prompt text may explain the fix,
   but must not be the enforcement boundary.
2. If the guidance is a repository or subsystem fact, route to the nearest
   `AGENTS.md` and canonical document. Do not copy the fact into a global rule.
3. If the guidance is a procedure selected by task intent, put it in a skill or
   explicit command and load it when needed.
4. If a high-signal regex or AST pattern can identify the mistake while the
   model is producing prose or tool arguments, use TTSR and test both positive
   and negative examples.
5. Keep guidance in the shared startup core only when it is relevant to nearly
   every task, cannot be loaded reliably later, and cannot be enforced by a
   deterministic mechanism.

The expected shared core is limited to scope preservation, consequential-action
authority, evidence versus assumption, source-of-truth discipline, and honest
completion claims. It contains invariants, not tutorials, command recipes,
examples, tool inventories, or motivational prose.

### OMP-specific policy

- Prefer TTSR for known mistakes that have a precise observable precursor.
- Prefer AST conditions over regex when syntax shape is the real signal and the
  supported edit/write stream exposes enough prospective source.
- Narrow every rule with `scope` and file globs where possible.
- Use interrupting rules only when aborting before the tool executes is safe and
  useful. Use non-interrupting tool reminders for guidance that becomes relevant
  after a successful command result.
- Treat `omp ttsr test` positive and negative fixtures as required evidence.
  Use `omp ttsr scan` to estimate false positives before broad activation.
- Keep rule bodies short: state the violated invariant, the preferred action,
  and the canonical skill, document, or command to consult.
- Do not encode account authorization, destructive-action approval, secret
  handling, or publication authority solely in TTSR. Those remain deterministic
  policy and explicit user-authority boundaries.

### Harness boundary

The taxonomy is harness-agnostic; the delivery mechanism is not. OMP gets the
first pilot because TTSR is present, observable, testable, and already in use.
Codex and Pi keep their current instruction wiring until the OMP evaluation
shows which rules can be removed safely and an equivalent native mechanism or
small adapter is chosen for each harness.

Do not emulate TTSR in another harness by injecting a large dispatcher prompt.
If a harness lacks dormant stream correction, use its native conditional rules,
skills, hooks, or deterministic tooling and accept a smaller shared core.

## Migration

### Phase 0: Record and baseline

- Keep this ADR as the decision boundary.
- Record the current generated prompt size and `omp ttsr list --json` inventory.
- Build a small scenario corpus from real failures: irrelevant-rule questions,
  dirty-worktree edits, jj/Git confusion, commit and PR writing, TypeScript
  violations, external writes, and legitimate plan-only requests.

### Phase 1: Prove TTSR rule quality

- Add positive and negative fixtures for the three existing local TTSR rules.
- Verify the intended stream, path, interrupt behavior, and repeat behavior.
- Measure false positives with `omp ttsr scan` and the scenario corpus.
- Change ambiguous regexes before migrating more guidance.

### Phase 2: Thin OMP's always-on context

- Replace the concatenated shared bundle in OMP with a small generated core.
- Remove the duplicate always-on incremental-architecture rule.
- Route Git, jj, testing, conversion, code-search, skill-location, and Nix
  procedures to their existing skills or repository documents.
- Convert only high-signal corrective fragments to TTSR. Move enforceable
  constraints to checks rather than duplicating them as reminders.
- Give the generated OMP startup instructions a word budget and fail validation
  when it is exceeded.

### Phase 3: Evaluate before expanding

- Run the same scenario corpus with the current and thin OMP configurations on
  the same model family and tool surface.
- Compare task success, unnecessary instruction loading, false interruptions,
  correction success, and user corrections.
- Keep the thin configuration only if safety and completion behavior do not
  regress materially.

### Phase 4: Adapt Codex and Pi separately

- Reuse the classification and scenario corpus, not OMP-specific frontmatter.
- Prefer each harness's native conditional loading and enforcement surfaces.
- Keep shared content semantic and small; keep adapters mechanical.

## Implemented pilot

The OMP pilot implements the source-controlled portions of Phases 0 through 3:

- `config/agents/core.md` is a 250-word-budgeted semantic core. Only OMP reads it;
  Codex and Pi retain the legacy bundle.
- `modules/agents/omp/default.nix` installs that core as OMP's global
  `AGENTS.md` and no longer installs the duplicate incremental-architecture
  rule.
- `config/omp/config.yml` explicitly enables discard-context, interrupting,
  once-per-session TTSR behavior and bundled rules.
- Four local rules have 33 named positive and negative CLI scenarios. Shell
  command boundaries prevent quoted search text from triggering them.
- `ci-watch` changed from always-on guidance to a non-interrupting post-tool
  TTSR reminder.
- Pre-commit, flake, and agent-finish gates run the core-wiring and TTSR
  scenarios. The generated prompt budget is enforced by the wiring test.

Host activation remains a separate authorized operation. Source-level tests and
Nix evaluation prove the configuration before `hey re` changes the live runtime.
The same-model current-versus-thin live comparison remains an activation
acceptance check; it is not simulated by adding the thin core on top of the
currently deployed legacy prompt.

## Consequences

Positive:

- Most task-irrelevant rules stop consuming startup context.
- Known mistakes can be corrected at the point of violation rather than weakly
  repeated at the beginning of every conversation.
- Rule matching becomes inspectable and testable through OMP's CLI.
- The architecture preserves portable concepts while allowing each harness to
  use its strongest native mechanism.
- Better models can shed obsolete scaffolding without deleting durable safety
  and authority boundaries.

Tradeoffs:

- TTSR conditions can false-positive, false-negative, or match only after the
  model has already spent tokens on a bad direction.
- AST matching sees prospective edit/write payloads, not arbitrary existing
  source, so it cannot replace repository lint or tests.
- OMP's first-wins rule-name deduplication can shadow a lower-priority rule;
  inventory and source metadata must be checked when behavior is surprising.
- Interrupted generations and hidden reminders add control flow that must stay
  visible through TTSR notifications and transcript evidence.
- The OMP pilot temporarily leaves Codex and Pi with a larger legacy bundle.

## Rejected alternatives

### Keep the concatenated bundle and only edit its prose

Rejected because it preserves the context tax and relevance problem. Shorter
wording helps, but does not make task-specific procedures universally relevant.

### Delete all standing guidance

Rejected because repository ownership, user authority, and recurring mistakes
still require durable handling. Thin means selectively loaded and enforced, not
undocumented.

### Convert every rule to TTSR

Rejected because many requirements have no precise stream signature. Broad
regexes would create surprising interrupts, while critical safety requirements
need deterministic enforcement.

### Wait for one portable conditional-rule standard

Rejected because OMP already provides a usable native mechanism and the
repository can evaluate it now. Portability belongs in the classification and
content, not in forcing every harness to expose identical internals.

## Verification and revisit criteria

Before accepting the Phase 2 configuration:

- `omp ttsr list --json` resolves every intended local rule from the expected
  source with the expected condition and scope.
- Every migrated rule passes named positive and negative `omp ttsr test`
  fixtures.
- Edit/write rules produce no unexplained broad matches under `omp ttsr scan`.
  Tool-command rules use explicit positive and negative fixtures because file
  scanning correctly reports them as having no relevant file scope.
- The generated OMP startup instructions remain under the adopted word budget.
- Scenario evaluations show no material regression in scope preservation,
  authority handling, observable verification, or completion honesty.

Revisit this ADR when TTSR matching or persistence semantics change, when a
second harness gains a comparable native mechanism, or when observed false
interruptions outweigh the removed context cost.

## Sources

Accessed 2026-08-12:

- [OMP TTSR overview](https://omp.sh/docs/ttsr)
- [OMP rulebook matching pipeline](https://github.com/can1357/oh-my-pi/blob/main/docs/rulebook-matching-pipeline.md)
- [OMP TTSR injection lifecycle](https://github.com/can1357/oh-my-pi/blob/main/docs/ttsr-injection-lifecycle.md)
- [Craft Context Dynamically, Not Statically source](https://share.snipd.com/snip/8a6ef33a-4dcb-4536-8262-f90d06f2d746)
- [Onboard Agents With Sharded Context source](https://share.snipd.com/snip/d566cb09-cbc4-4246-ab44-6ff474849f9e)
- [Building pi in a World of Slop source](https://share.snipd.com/episode/3cd6de1e-4dc9-4231-84e6-4f25a2f66494)
- [Inside Claude Code From the Engineers Who Built It source](https://share.snipd.com/episode/ca58b682-e850-42e0-afed-6daa6466d058)
