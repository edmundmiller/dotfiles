---
purpose: Route cheap recurring work to cheap models; pin models on scheduled tasks.
rule_id: AGENT-17
enforced_by: prompt
severity: warn
waiver_path: .agents/waivers/AGENT-17.md
---

# Model Routing

Route by job, not habit:

- **Smol/haiku-class**: lookups, digests, summarization, script-relay, polling loops.
- **Default/frontier**: implementation, debugging, judgment calls.
- **Scheduled/recurring tasks MUST pin an explicit model** — never inherit session default.

Per-CLI levers:

| CLI    | Lever                                                  |
| ------ | ------------------------------------------------------ |
| claude | `model:` in SKILL.md frontmatter; `/model` in-session  |
| omp    | `--smol` / roles                                       |
| codex  | `--profile triage` (cheap) / `--profile review` (high) |
| pi     | `pi-model-switch`                                      |
