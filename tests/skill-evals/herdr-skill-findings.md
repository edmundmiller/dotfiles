# Herdr skill eval — findings

Measured with `tests/skill-evals/herdr-skill.eval.ts` against herdr 0.7.5,
runner `claude -p`, blind rubric judge, n=3 on contested cases.

Historical: these numbers are from the 0.7.5 sweep and have not been re-measured
against 0.8.0. The executable corpus, shim, and tests are pinned to 0.8.0; rerun
the eval before treating any figure below as current.

## Arms

| Arm        | Context                                                       |
| ---------- | ------------------------------------------------------------- |
| `helpOnly` | No docs. Told the installed CLI is the source of truth.       |
| `minimal`  | Help preamble plus ~25 lines of help-inexpressible semantics. |
| `full`     | The current skill: `SKILL.md` + `cli-map.md` + `recipes.md`.  |

All arms get identical tasks, identical tool access (`Bash` only), and an
identical JSON output contract. Only the context block differs.

## Results

All numbers come from the final harness: help replayed from a captured corpus,
with the herdr IPC socket denied by an OS sandbox. Two earlier sweeps are
discarded -- the first ran with the shim bypassed entirely, the second with an
absolute-path hole that still reached the live session. Both are unusable for
help counts, and neither actually enforced "do not mutate".

Full sweep, all 8 cases (n=1 per cell):

| Arm        | Passed | Median help calls |
| ---------- | ------ | ----------------- |
| `helpOnly` | 4/8    | 11.5              |
| `minimal`  | 7/8    | 8.5               |
| `full`     | 8/8    | 5                 |

Failures are consistent across arms: `helpOnly` misses
`background-completion-unfocused`, `rename-consistency`, `service-output-wait`
and `start-and-prompt`; `minimal` misses only `start-and-prompt`.

No hallucinated commands and no stale syntax in any of the 24 runs.

## Conclusion

**Keep the full skill.** It is the only arm that passes every case, and it does
so with the fewest help invocations. Help calls dominate wall time -- the sweep
took 1085s, almost entirely `--help` round trips -- so the context is both more
accurate and cheaper than rediscovery.

`minimal` is close but not sufficient. Its one failure, `start-and-prompt`, is
0/3 when repeated under the final harness (full is 3/3): it omits that
`agent prompt` submits the text and Enter together, which no amount of help
reading supplies. Any future trimming must keep that fact.

`helpOnly` fails exactly the classes the skill was written for: idle-vs-done
focus semantics, rename drift, prompt submission, and output waiting. Help
output is sufficient for flag spelling and little beyond it.

## Four instrument bugs found (and fixed)

The first two initially looked like full-skill failures. Neither was.

1. `requiredCommands` demanded the literal string `root_pane`, which scored the
   brittle hand-written key path above `extract_ids.py` -- the helper the skill
   recommends precisely because it absorbs the `root_pane`/`pane` difference.
   Fixed with `anyOfCommands`, accepting either correct approach.
2. The `workspace-root-pane-shape` task never asked about the shape difference,
   so a correct plan that sidestepped it via `extract_ids.py` was marked as not
   demonstrating knowledge it was never asked to state. The task now asks.
3. **The shim was bypassed entirely in the first sweep.** Claude's Bash tool
   uses a login shell; `/etc/zprofile` rebuilds `PATH` and put the real `herdr`
   ahead of the temp-dir shim. Help calls went uncounted and "do not mutate"
   was never enforced. Partially fixed with a `herdr` function in a per-run
   `ZDOTDIR`, plus `set -e` so a failed log append aborts instead of failing
   open.
4. **The ZDOTDIR function was itself bypassable.** Any interception keyed on
   the _name_ loses to an absolute path, and
   `/etc/profiles/.../herdr pane list` was verified to run live and dump real
   pane data. Denying the binary is no better -- `cp herdr /tmp/evil` defeats
   it. Fixed by attacking the capability instead: help is replayed from a
   captured corpus so the shim never execs herdr, and `sandbox-exec` denies the
   IPC socket directory, so every route fails regardless of binary.

Bugs 3 and 4 each invalidated a completed sweep; both were discarded and
re-measured rather than reinterpreted.

Lessons: when an arm with _more_ correct information scores worse, suspect the
scorer before concluding the information hurt. A control is not a control until
you have watched it block something. And name-based interception is not
containment -- deny the capability.

## Validity controls

Each was verified live inside the real runner, not assumed:

- **Config isolation.** Empty temp cwd, `--setting-sources ''`, `--tools Bash`.
  Without it the process inherits project/user CLAUDE.md, settings, and the
  installed herdr skill.
- **Filesystem isolation.** `sandbox-exec` denies reads of the dotfiles repo,
  `~/.agents`, and `~/.claude`. `--tools Bash` alone does NOT stop
  `cat /abs/path/SKILL.md`; verified that the read succeeds without the sandbox
  and returns `Operation not permitted` with it.
- **Capability denial.** The sandbox denies `~/.config/herdr`, the IPC socket
  directory. Regression-tested against the three bypasses that defeat
  name-based interception: absolute installed path, resolved `/nix/store`
  path, and a copied binary. Each is asserted to fail _with a permission
  error and no pane data_, so an unrelated launch error cannot masquerade as
  containment.
- **Hermetic help.** Help is replayed from `herdr-help-corpus.json`, captured
  by `capture-herdr-help.py` and pinned to the installed version by a test.
  Exact matches only: an uncaptured path exits 66 rather than approximating,
  so a hallucinated subcommand cannot be laundered into a plausible reply.
  Bare `herdr` is refused -- it attaches a session, it is not a help route.
- **Fail-closed auditing.** If the log cannot be written the shim refuses the
  call. `helpInvocations` is counted from that log, never self-reported.
- **Semantic grading.** The rubric judge grades meaning, not wording, since the
  lexical fallback rewards arms whose injected text contains the reference
  phrasing. Determinism checked at 5 repeats in both directions.

Session integrity: 9 agents / 18 panes before and after. That check is weak on
its own -- counts cannot detect prompts, renames, or in-place mutations. Socket
denial is the real control; the shim provides recording and usable help.

## Caveats

- n=1 per cell on the full sweep. Only `start-and-prompt` was repeated (n=3)
  under the final harness; the other single-cell differences between `minimal`
  and `full` are not individually significant.
- One runner (`claude -p`) and one judge model. The codex backend shares the
  same shim, sandbox, and counting path but is unexercised (binary absent).
- Cases are held out from the trace corpus that authored the skill's pitfalls
  section, but were written by the same agent that wrote the skill.
