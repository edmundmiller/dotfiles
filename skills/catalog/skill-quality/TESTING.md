# Skill Testing Guidelines

Test structure deterministically, then test model behavior with observable scenarios.

## Test Layers

1. **Structure:** metadata, size, links, and portability markers
2. **Invocation:** positive and negative trigger phrases
3. **Execution:** common path, failure path, and verification behavior
4. **Models:** Terra and Sol follow the same contract
5. **Real usage:** a fresh task without hidden author context

## Evaluation Case

Record cases in a form another reviewer can rerun:

```markdown
### Case: <name>

- Model: Terra | Sol
- Input: <exact user request>
- Setup: <repository state, files, permissions, and available tools>
- Expected invocation: yes | no
- Required actions: <observable behavior>
- Forbidden actions: <scope or authority boundaries>
- Verification: <command, artifact, or state reread>
- Result: pass | fail
- Evidence: <short transcript, paths, or output>
```

Do not score writing style when the contract is about files, commands, or state. Prefer exact artifacts and exit codes.

## Minimum Scenario Set

### 1. Common path

Use the request most likely to trigger the skill. Verify:

- the skill activates
- prerequisites appear before action
- the shortest valid workflow is followed
- the stated success check is exercised

### 2. Negative invocation

Use a nearby request owned by another skill or ordinary reasoning. Verify that this skill does not activate or distort the response.

### 3. Failure path

Remove a dependency, provide malformed input, or deny an expected permission. Verify:

- the failure is identified accurately
- no destructive workaround is invented
- the recovery instruction is actionable
- the task is not falsely reported complete

### 4. Ambiguous or high-risk path

Provide a case with multiple plausible interpretations or consequential mutations. Verify that authority and scope stay explicit.

## Terra Pass

Terra is the balanced default for everyday tool-heavy work. Test the common and failure paths first.

Common Terra regressions to watch:

- a late prerequisite is missed
- a long paragraph hides a branch
- verification is summarized instead of run
- runtime-specific tool language is treated as universally available

Fix these with earlier constraints, shorter steps, explicit decision points, or scripts. Do not add redundant prose.

## Sol Pass

Sol is the frontier choice for hard debugging, implementation, and synthesis. Test the ambiguous or high-risk path.

Common Sol regressions to watch:

- expanding scope to produce a more elegant system
- adding abstractions not required by the request
- replacing an explicit workflow with a plausible alternative
- treating broad reasoning as stronger evidence than runtime state

Fix these with clear stopping conditions, protected boundaries, and direct evidence requirements.

## Cross-Model Comparison

Run one identical case on Terra and Sol. The wording may differ; these must not:

- invocation decision
- authorization boundary
- files or systems in scope
- required validation
- completion threshold

If behavior differs, first remove ambiguity from the skill. Add model-specific wording only when the capability difference is genuinely part of the workflow.

## Testing Scripts

For a skill with executable helpers, cover:

- valid input returns zero
- each supported invalid class returns nonzero
- errors name the file or input and explain recovery
- structured output parses successfully
- repeated runs are deterministic
- no secret value is printed

Keep model evaluation out of Git hooks. Hooks should run deterministic checks only.

## Real-Usage Check

Use the skill from a fresh task or repository state. Record where the agent needed information not present in `SKILL.md` or its direct references. Add only durable, reusable guidance.

Re-run relevant cases after trigger, workflow, script, or safety-boundary changes.
