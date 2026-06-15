# Pi session autonomy audit

Date: 2026-06-15

## Sources inspected

- `~/.pi/agent/sessions/--Users-emiller-.config-dotfiles--/*.jsonl`
- `~/.pi/agent/sessions/--Users-emiller-obsidian-vault--/*.jsonl`
- `~/.pi/agent/sessions/--Users-emiller-src-fg-nascent-manuscript--/*.jsonl`
- `~/.pi/agent/sessions/--Users-emiller-.local-share-herdr-worktrees-dotfiles-*/*.jsonl`
- `~/.pi/agent/pi-debug.log`
- `~/.pi/agent/pi-crash.log`
- `~/.pi/logs/pi-dcp.log`
- Focus reads via `session_read`:
  - `2026-02-04T00-24-40-847Z_e69e24e1-70e9-4a67-ab26-e40d474dc436.jsonl`
  - `2026-03-05T03-33-23-997Z_94a91f18-741b-4105-a769-f72100a8a92b.jsonl`
  - `2026-03-06T23-10-24-042Z_6aa4bfc6-ba34-408a-aa74-c3b1f8b64588.jsonl`
  - `2026-03-12T12-04-36-374Z_807bd892-bb65-4583-b37a-719b4ca0eb06.jsonl`
  - `2026-05-23T02-57-13-402Z_019e52c3-f0ba-73f9-9b51-a6d3bad4d6c4.jsonl`

## Aggregate scan

A local JSONL scan counted likely manual re-prompts after the first user message, using terms such as `continue`, `try again`, `did that`, `how's`, `okay`, and explicit goal continuations.

| Project/session group    | Sessions | User messages | Tool calls | Likely manual re-prompts | Bad-ending markers | Final validation mentions | Goal mentions |
| ------------------------ | -------: | ------------: | ---------: | -----------------------: | -----------------: | ------------------------: | ------------: |
| dotfiles                 |      744 |          4375 |      63044 |                      551 |                102 |                       180 |             1 |
| dotfiles Herdr worktrees |       17 |           183 |       1643 |                       36 |                  3 |                         7 |             0 |
| nascent manuscript       |       19 |           175 |       3766 |                       11 |                  1 |                         4 |             0 |
| Obsidian vault           |      272 |          1775 |      20460 |                      262 |                 32 |                        42 |             1 |

The scan is heuristic, but the imbalance is useful: many sessions have many follow-up kicks, while durable goal use is rare in the inspected project histories.

## Recurring failure patterns

1. **Agents stop at advice before using local tools.** The `019e52c3...` Obsidian task session began with generic task-system recommendations before adapting to the existing `tnote`/Flue setup, causing multiple corrective prompts.
2. **Agents need user nudges to close the loop.** Obsidian sync sessions show a better pattern only after direct prompts: check logs, deploy, remove stale dirs, wait, and re-check. That loop should be default for sync/debug tasks.
3. **Validation is inconsistent.** Short nascent manuscript fixes did validate `pixi info`, but aggregate scans show many final answers without fresh test/build/smoke evidence.
4. **Long sessions drift without a durable contract.** Dotfiles and Obsidian sessions often span dozens of user turns and hundreds of tool calls with no goal/checkpoint marker in the JSONL, making it easier to stop at partial state or require manual direction.
5. **Final answers sometimes leave agent-actionable work as “next steps.”** Bad-ending markers include `next steps`, `not run`, `could not`, `if you want`, and `remaining`, even when the session had enough local access to continue.
6. **Logs reveal runtime/tooling rough edges but not the main autonomy issue.** `pi-crash.log` captures a rendering crash around terminal width; `pi-dcp.log` shows pruning activity. The main re-prompt pattern is behavioral: missing outcome contracts and completion audits.

## Changes made

- Added shared rule `config/agents/rules/16-autonomous-goal-progress.md` so Pi/Claude/OpenCode prompts explicitly require durable outcome contracts, iteration after partial attempts, no stopping at plans, blocked-stop evidence, and final completion audits.
- Added global skill `skills/catalog/autonomous-agent-loop/SKILL.md` for broad/cross-session work, createGoal usage, manual-kick investigations, and evidence-first debugging.
- Added this audit note as a durable source of the inspected evidence and rationale.

## Expected effect

Future Pi sessions should more often:

- create or continue durable goals for broad tasks
- inspect evidence after each attempt instead of waiting for the user to say “continue”
- run validation/smoke checks before final “done”
- patch durable repo surfaces (`AGENTS.md`, skills, prompts, docs) rather than only summarizing recommendations
- report exact blockers only when actual access/tool/decision limits prevent completion
