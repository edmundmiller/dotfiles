# Agent Design Philosophy

## The Core Problem

AI coding agents have seen millions of git workflows in training data but almost zero jj or GitButler workflows. This creates three failure modes:

### 1. Git Mental Model Leakage

Agents default to git's commit model: "make change, stage, commit, make change, stage, commit" as a linear sequence. They don't internalize:

- **jj's working copy IS a commit.** You describe it, evolve it, then `jj new` to start the next one. There's no "staging" step.
- **`jj new` creates a child, not a checkpoint.** It's "I'm done with this, start the next thing" — the opposite of `git commit` which is "save what I have."
- **Commits are mutable by default.** You can `jj describe`, `jj squash`, `jj rebase` freely. There's no "amend" ceremony.

### 2. One-Off Commit Syndrome

The most common agent failure: create a single commit with all changes instead of building proper stacks. The agent treats jj like git — dump everything into one commit and move on. This defeats the entire purpose of jj's mutable, stackable history.

**What agents do:**
```bash
# Write all files
echo "auth" > src/auth.rs
echo "profile" > src/profile.rs
echo "settings" > src/settings.rs
jj describe -m "add auth, profile, and settings"
# One giant commit. Done.
```

**What they should do:**
```bash
jut branch auth
echo "auth" > src/auth.rs
jut commit -m "add authentication"
jut branch profile --stack
echo "profile" > src/profile.rs
jut commit -m "add user profiles"
jut branch settings --stack
echo "settings" > src/settings.rs
jut commit -m "add settings page"
# Three stacked commits, each reviewable independently.
```

### 3. The GitButler Problem

GitButler (`but`) has a different failure mode: agents crash out when applying multiple virtual branches simultaneously. The setup/teardown boundary between `but` and raw `git` means you can't drop out to git and come back — your virtual branches get confused.

jut intentionally avoids this. There's no setup, no teardown, no virtual branch state. `jut` and `jj` are fully interchangeable at any point. An agent can use `jut commit` then `jj split` then `jut push` without any state corruption.

## How jut Addresses This

### Strategy 1: `--status-after` Forces State Awareness

The single most important flag. After every mutation, the agent sees the current workspace state — what changed, what's pending, where it is in the stack. This breaks the "plan from memory" pattern that causes failures.

Agents that use `--status-after` succeed because they **react to state** instead of **executing a memorized git-like sequence**.

### Strategy 2: The Skill Teaches the Model

`jut skill install` puts a SKILL.md into the project that teaches:

- Non-negotiable rules (always `--json --status-after`)
- The jj commit model (not the git model)
- Task recipes (not command references)
- When to drop to raw `jj` (interactive commands)

The skill is the primary leverage point. Improving it based on eval failures has more impact than new features.

### Strategy 3: Evals Measure Compliance

`skill/eval/` runs agents through realistic scenarios and checks:

- Did they use `jut` commands (not raw git)?
- Did they use `--json --status-after`?
- Did they check status before mutating?
- Did they build proper stacks (not one-off commits)?
- Did they drop to `jj` for interactive work (not attempt `jut split`)?

### Strategy 4: Opinionated Verbs Hide the Model

`jut commit` = `jj describe` + `jj new` in one step. The agent doesn't need to understand jj's "describe then new" pattern — it just says "commit this with message X" and gets the right behavior.

`jut branch feature --stack` = `jj new` + `jj bookmark set` with the right base. No need to figure out revision specs.

`jut discard` = auto-detect file (restore) vs revision (abandon). One verb, not two.

## What jut Intentionally Doesn't Do

- **No TUI.** That's `jj` + lazyjj territory.
- **No interactive commands.** `split`, `resolve`, `rebase -i` — use `jj` directly. Agents can't drive interactive UIs anyway.
- **No jj-lib dependency.** Pure CLI wrapping keeps semantics identical to jj. If jj changes behavior, jut follows automatically.
- **No daemon/server/state.** No setup, no teardown. Mix `jut` and `jj` freely.
- **No config system.** jj's config is enough.

## The Eval Loop

The path to reliable agent behavior is:

1. Run evals → find failure modes
2. Tune SKILL.md → address the specific failures
3. Re-run evals → measure improvement
4. Repeat

The skill is living documentation. The eval is the test suite. New jut commands are only justified when they eliminate a class of agent failures that the skill alone can't fix.

## Future Directions

**`jut agent start/checkpoint/done/stack`** — 4-command workflow that eliminates the jj mental model entirely. The agent doesn't need to understand `jj new` vs `jj commit` — it just says "I'm starting work" and "I'm done with this piece." This is the nuclear option if skill tuning plateaus.

**Prescriptive status output** — Instead of just showing state, suggest the next command. "You have uncommitted changes in 3 files. Run `jut commit -m '...'` or `jut branch <name>` to start a new feature." Turn status into a workflow guide.

**Multi-commit eval scenario** — The critical test: "make 3 related changes that should be 3 stacked commits." Run 20 times, measure how often agents collapse them into one commit. This is the metric that matters.
