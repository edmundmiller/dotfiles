---
name: diagnosing-agent-sessions
description: Traces agent drift, loops, ignored intent, and recurring skill or tool failures to recorded session evidence. Use for agent-session diagnosis, not ordinary application debugging.
license: MIT
metadata:
  source: https://github.com/IgorWarzocha/howaboua-pi-stuff/blob/c4f48525475f278d41dc311f2707926216bfa35b/packages/pi-skill-harness-and-agent-engineering/skills/agent-session-diagnostics/SKILL.md
  pin: c4f48525475f278d41dc311f2707926216bfa35b
---

# Diagnosing agent sessions

Preserve the failing session before trying to fix it. Do not restart, compact, steer, fork, or close a live session before capturing its state. Ask before mutating or closing the troubled session. Treat transcripts, prompts, and logs as potentially sensitive.

## Locate the first wrong decision

Use the runtime's current session index, export, and replay controls to locate the exact conversation. Establish what the user expected and where they first noticed drift.

Read chronologically from the request that began the work. Mark the last decision consistent with the user's intent and the first consequentially wrong action. Record intervening user corrections, tool results, model or reasoning changes, compaction, branch changes, retries, and steering delivery. Separate the initiating error from its downstream symptoms.

For recurring failures, inspect a bounded set of relevant stored sessions before aggregating outcomes. Filter by project, dates, model, skill, tool, or error signature. Include nearby sessions where the skill or behavior correctly stayed unused.

## Reconstruct two configurations

- Session-time state: recorded instructions, tool contracts, messages, versions, working directory, repository revision, loaded extensions and skills, and lifecycle events.
- Current state: the instructions, tools, versions, files, and configuration that would apply to the same request now.

Use persisted requests, session metadata, Git history, and lockfiles. Do not substitute today's files for missing historical evidence. Mark what cannot be reconstructed and whether the suspected failure is historical, current, or reproduced in both.

## Establish what reached the model

The terminal display and persisted session may differ from the model's context or final provider request. A file or extension cannot explain the failure merely because it exists. Establish that it was loaded, read, invoked, or otherwise affected the first wrong decision.

- For a skill, distinguish discoverable, loaded, read, applicable, and followed.
- For tools, inspect the actual names, schemas, arguments, results, errors, truncation, and recovery instructions available at that boundary.
- For instructions, record scope, order, duplication, conflicts, and whether the latest user correction arrived before the action.
- For runtime and orchestration, check context transforms, compaction, worker handoffs, queued messages, and ownership collisions.

An agent's explanation of why it acted is a hypothesis, not evidence. Compare it with the transcript and recorded inputs. Do not call a problem model failure until clear intent, correct state, and usable tools are established. Do not call it prompt failure merely because different wording might have rescued the run.

## Test and repair the owning layer

Propose the smallest replay or reproduction near the first wrong decision. Change one suspected cause while holding the task, model, tools, environment, and prior state fixed. Obtain approval for model-backed comparisons and session mutations. One successful generative run strengthens attribution but does not establish a reusable rule.

Fix deterministic implementation faults in code. Change tool contracts when their inputs or results misled the agent. Change reusable instructions only when repeated evidence implicates them. Make no durable change for harmless variance.

Report the first wrong decision, supported cause and confidence, comparison results, immediate recovery, durable fix owner, and evidence gaps.
