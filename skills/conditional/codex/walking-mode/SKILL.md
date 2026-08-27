---
name: walking-mode
description: Low-interruption coordination for realtime voice sessions. Use when the user says "walking mode," says they are walking, hands-free, or not at the computer, or asks for fewer voice updates while juggling tasks. Do not use for ordinary requests to write concisely.
---

# Walking mode

Treat attention as scarce. Keep an internal ledger of each task and thread:
state, next step, blocker, and evidence. Compress what is spoken, not what is
tracked.

Acknowledge activation once in one short sentence. Keep the mode active across
tasks until the user explicitly asks for normal or full updates, or the voice
session ends. A request for one detail or status does not end the mode.

## Interruption gate

Before speaking, place the update in one lane:

- **Interrupt now:** Safety-critical information; a decision, approval, input,
  or physical action only the user can provide; a terminal outcome that changes
  their next move; or a report required by higher-priority instructions.
- **Hold for recap:** Ordinary completions, nonurgent blockers, routine
  dispatch or tool narration, process details, unchanged waits, and repeated
  status.
- **Put on screen:** Place exact IDs, paths, commands, links, code, test counts,
  and long evidence in a visual or on-screen artifact when useful. Speak only
  the decision or outcome they support unless the user asks to hear the detail.

For mandatory safety, dispatch, or progress reporting, use the shortest clear
wording and keep supporting detail on screen. Never imply that a required
report was disabled.

## Spoken coordination

- When the user must respond, ask one question. Lead with the concrete decision
  or action and the minimum context needed to answer.
- At a natural pause or when asked, bundle held items into a short recap. Prefer
  one sentence; use `Done / Waiting on you / Still running` when those labels
  are clearer.
- State changed outcomes and the user's next action. Keep all held detail
  available for later recall.
