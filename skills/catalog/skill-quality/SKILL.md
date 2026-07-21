---
name: skill-quality
compatibility: portable
description: Validate and review agent skills for portable structure, clear triggers, executable helpers, and reliable behavior across Terra and Sol.
---

# Skill Quality

Use this skill when creating or revising a skill, debugging invocation, reviewing a skill catalog, or moving repeatable prose into a script.

## Start with the Deterministic Gate

Run the shipped validator before model review:

```bash
python3 ~/.agents/skills/skill-quality/scripts/validate.py path/to/skill
```

In this dotfiles repository:

```bash
python3 skills/catalog/skill-quality/scripts/validate.py \
  skills/catalog .agents/skills skills/conditional
```

Use `--json` for structured output. Fix every reported finding before judging prose quality.

The validator enforces:

- `SKILL.md` with closed YAML frontmatter
- non-empty `name` and `description`
- lowercase hyphenated name matching the skill directory
- description length at most 1024 characters
- `SKILL.md` at most 500 lines
- existing local Markdown references
- no known runtime-specific tool names when `compatibility: portable` is declared

These are structural requirements. They do not prove that instructions are correct or useful.

## Choose the Directory Shape

- **`SKILL.md` only:** short trigger and workflow guidance
- **`references/`:** longer examples, troubleshooting, or command reference
- **`scripts/`:** repeatable validation, generation, migration, or inspection
- **`assets/`:** templates, fixtures, or static inputs

Keep the entrypoint focused on decisions and the shortest successful workflow. Supporting files should be reachable directly from `SKILL.md`; avoid reference chains.

## Review the Judgment Layer

### Trigger quality

- Say what the skill does and when it should activate.
- Use phrases users naturally say.
- State important exclusions when adjacent skills overlap.
- Keep the description specific enough to avoid accidental invocation.

### Workflow quality

- Put prerequisites and authority boundaries before mutations.
- Use numbered steps for sequences and decision points for branches.
- Include exact verification for consequential actions.
- Distinguish local checks, deployed state, and user-visible proof.
- Do not assume a tool exists unless the skill is intentionally runtime-specific.

### Example quality

- Make examples runnable or label them as pseudocode.
- Show expected output or a concrete success condition.
- Explain placeholders.
- Prefer one representative example over repeated variants.

### Script quality

- Solve the repeatable problem instead of asking the model to reinterpret prose.
- Return nonzero on findings and print actionable file-scoped errors.
- Offer structured output when another tool may consume results.
- Keep dependencies explicit, paths portable, and secrets out of output.
- Test success, failure, and malformed-input paths.

Move checks into scripts when the result depends only on parseable state. Keep tradeoffs, intent, and exception handling in prose.

## Test on Terra and Sol

Both models should obey the same safety, scope, and verification contract. Test different failure tendencies, not different requirements.

### Terra: balanced default

Use common and moderately complex cases. Look for:

- missed prerequisites hidden late in the skill
- ambiguous branches that require excessive inference
- skipped verification or premature stopping
- instructions that depend on unavailable runtime tools

### Sol: frontier reasoning

Use ambiguous, high-risk, or cross-system cases. Look for:

- speculative abstraction or scope expansion
- overriding explicit authority boundaries with a clever alternative
- unnecessary delegation or process overhead
- plausible claims supported only by indirect checks

### Cross-model invariant

Run at least one identical scenario on both models. Compare observable behavior:

- correct invocation
- same protected boundaries
- same required artifacts
- same verification threshold
- no model-specific tool assumption for portable skills

Broad shared skills need both model passes. Narrow mechanical skills may use one shared scenario plus deterministic script tests. Record evidence; do not claim cross-model compatibility from prose inspection alone.

See [TESTING.md](./TESTING.md) for the evaluation template and scoring guidance.

## Review Checklist

1. Run `scripts/validate.py`.
2. Confirm trigger, scope, exclusions, and authority boundaries.
3. Exercise the common path and one real failure path.
4. Test Terra and Sol in proportion to skill breadth and risk.
5. Move any newly discovered deterministic invariant into the validator or a skill-local script.

## Resources

- [EXAMPLES.md](./EXAMPLES.md) — concrete content and script patterns
- [TESTING.md](./TESTING.md) — Terra/Sol evaluation design
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — invocation and structure failures
