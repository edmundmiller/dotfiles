# Worklog: workspace-2qf.5

Status: complete

## Objective

Unify the NUC Hermes fleet on v0.20.5, deploy five native Buzz-facing bots
with final-only presentation and real smart approvals, preserve the internal
Orchestrator boundary, and stop only after authoritative live and remote
landing proof.

## Decisions

- Use the canonical agents-workspace renderer for runtime behavior and this
  repository only for host package, secret, service, and deployment wiring.
- Keep exactly one message-processing transport per Buzz identity; retain a
  separate presence-only publisher until native Buzz supports presence.
- Roll out from clean task worktrees and migrate one profile at a time.

## Evidence

- Agents-workspace start revision: `7d578928772ad5ffc81266930a7ce7b6720606ce`.
- Agents-workspace policy/topology revision: `8bd13f818ae8cf557c9092f2a5b264d8aa2a387b`.
- Agents-workspace final revision: `464867a4f6c5db36fe73b624a879ef4f6ed79937`.
- Dotfiles start revision: `baf5a44155b16ee6e0144a0ddbda2fc920596876`.
- Receipts:
  - `/Users/emiller/.local/state/dotfiles-agent-runs/d15c9afe3310/20260824T033804Z-f4649128e143.json`
  - `/Users/emiller/.local/state/dotfiles-agent-runs/908b31f00425/20260824T033921Z-5e73fce5ea11.json`
- Agents-workspace full flake check passed; the focused native Buzz suite passed
  11 tests. Remote `origin/main` was read back at the landed revision. A live
  repeat-activation failure then exposed a recursive ownership bug in the cron
  sync activation path; regression, fix, and pipe-safe assertion commits were
  landed as `19c2fb3`, `38e5fa4`, and `4a877ea`, producing the final revision.
- The repinned `hey nuc-wt build` built the all-native NUC generation at
  `/nix/store/rmhkj2cwpz86v09irb8ya3ryx3ybblbc-nixos-system-nuc-26.11.20260714.18b9261`.
  After making Buzz typing explicit, the final deployed closure is
  `/nix/store/zjnwvi7i7g1yrrfjamphp66xyr3nabfq-nixos-system-nuc-26.11.20260714.18b9261`.
- NUC builds passed for the all-native fleet assertions, Scintillate-only
  staged assertions, shared v0.20.5 package, external cron executor, and cron
  failure summary.
- The exact NUC Buzz derivation passed 20 focused tests with zero failures,
  including `dont-ask`, `dontAsk`, inherited systemd environment, and ACP wire
  rejection. This closes the staged ACP auto-allow release blocker.
- Pre-switch live baseline is generation
  `/nix/store/4xzl157286dlcdmqy8z50xfm43a10xgb-nixos-system-nuc-26.11.20260714.18b9261`:
  Scintillate native plus presence are active at v0.20.5; Finn, Amos Burton,
  Anne, and Betty ACP lanes are active; their native gateways are masked; all
  reported `NRestarts=0`. Orchestrator remains v0.19.1.
- The NUC has no deployment lock or active rebuild process. Its pre-existing
  degraded state is from failed Mill Docs pull/coding-agent and Obsidian vault
  dirt-check units, not a Hermes unit.
- Two consecutive switches of the final generation exited successfully. The
  second switch did not restart any gateway. Full `profile.yaml` byte hashes
  and all asset listings were identical before and after both activations; the
  five user-facing profiles remain visible and Orchestrator remains hidden.
- Live readback shows all six containers on Hermes Agent v0.20.5, all five
  native gateways and presence companions active/enabled with `NRestarts=0`,
  Orchestrator active without Buzz, and no legacy `buzz-hermes-*` unit files or
  loaded units. The host remains degraded only because the pre-existing Mill
  Docs pull and coding-agent units are failed; no Hermes fleet unit is failed.
- All six live configs enforce smart approvals, cron deny, automatic tool-use
  enforcement, Bot Mode protocol, and warning plus hard-stop loop guards. The
  five visible bots suppress tool/interim/reasoning/streaming/long-running/busy
  display noise, explicitly enable Buzz typing with the transient gear, retain
  threaded replies, and retain Discord typing for Anne and Betty.
- Podman preserved shell-style quotes in the five encrypted Buzz environment
  files, so native gateways initially received a quoted JSON string instead of
  the required JSON tag array. The shared agents module now parses dotenv input
  with `python-dotenv`, writes a private root-only runtime env file, hashes the
  normalized material, recreates a container when that material changes, and
  removes staging files on every exit. The focused module check passed on both
  aarch64-darwin and x86_64-linux.
- Dotfiles commit `b163fcc4e` pins the final agents revision. The fixed live
  generation is
  `/nix/store/d0fnn5l4yn76cyq7d3j1cfjk91fnain6-nixos-system-nuc-26.11.20260714.18b9261`.
  All five live process environments now parse `BUZZ_AUTH_TAG` as a JSON array
  with no outer string layer; all runtime env directories are mode 0700 and
  empty after pre-start.
- The first fixed switch replaced all five native containers. A second switch
  retained the same five container IDs, all six `profile.yaml` hashes, all six
  env-material hashes, active services, and `NRestarts=0`.
- Fresh native Buzz acceptance observed each positive thread for 208 seconds.
  Scintillate (`c7c2030c` -> `654ce7f3`), Amos Burton (`517bb6f4` ->
  `32b4536b`), Anne (`6fdd1618` -> `d27d2087`), Betty ambient meal-planning
  (`dfde4688` -> `5e599cd5`), and Betty mentioned mill-docs (`356e657e` ->
  `1cd9269f`) each produced exactly one same-thread final and no lingering
  reaction. Unmentioned Betty mill-docs root `57bc1eab` produced no reply.
- Local parse and `git diff --check` passed for every changed Nix source.
- The repository-wide local flake evaluation still reaches the pre-existing
  aarch64-darwin `chip-ota-provider-app` x86-only failure. The unrelated
  `nuc-hermes-cron-executors` check still expects a retired Radar unit; neither
  failure is in this task's changed behavior.
- Literal-mention acceptance on native Scintillate preserved the exact unknown
  mention in `@NotARealBuzzMember LITERAL-MENTION-OK
20260824T090207Z-LIT2`, in one same-thread final with no duplicate after the
  92-second observation window.
- Smart-approval acceptance produced a HIGH-risk native Buzz approval control
  for a deliberate pipe-to-interpreter request, accepted the explicitly
  mentioned `/deny`, emitted one denial final, and left no execution evidence.
- Transient-working acceptance observed `⚙️` appear for root `a5b54a7` at
  09:07:15Z, disappear at 09:07:37Z, and leave one same-thread final with no
  residual reaction or delayed duplicate.
- The reply lifecycle patch was subsequently hardened so only the gateway's
  authoritative authorization result can seed exact-mention retry provenance.
  It also hands retained reaction-cleanup state to a replacement adapter. The
  exact v0.20.5 package passed 20 focused tests in source and in the deployed
  package closure.
- Agents-workspace `origin/main` is now `9562a09f2df2c49347534fcce29989729bb5ae99`.
  The nine reviewed dotfiles fleet commits were published patch-equivalently
  to `origin/main` at `c29dac6fbd957635ed829be0ffe9162a8f31dd0d`.
- A daily canonical NUC deploy began from the pre-publication GitHub revision
  while the task worktree switch was finishing. It restored the safe
  Scintillate-only staged selector: Scintillate remained native while Finn,
  Amos Burton, Anne, and Betty returned to one permission-denying ACP lane;
  no identity had duplicate message-processing transports. The canonical
  source is now published, so the final switch will use the durable all-native
  selector.
- The published canonical tip was then switched from a clean detached checkout
  to generation
  `/nix/store/42wsps21jhjw50pg8bsm6xmli5hd9fzf-nixos-system-nuc-26.11.20260714.18b9261`.
  The switch's nonzero status was solely the pre-existing Mill Docs coding-agent
  TypeScript failure; the Hermes units were activated successfully.
- The first readback caught Amos's config still at its pre-policy hash. A
  second activation of the identical generation converged it to the intended
  `813f30dd...` hash without recreating any of the five native containers. A
  representative Amos cron tick then preserved that hash and exited zero.
- Fresh authoritative YAML and roster assertions pass for all six profiles:
  fleet safety policy everywhere; final-only Buzz settings and transient gear
  on the five visible bots; Discord final-only settings and typing on Anne and
  Betty; and hidden/no-Buzz Orchestrator. All six gateways plus all five
  presence-only companions are active with `NRestarts=0`; every companion logs
  `respond_to=nobody`; no legacy `buzz-hermes-*` unit is loaded or installed.
- The atomic reconnect ownership regressions and fix landed patch-equivalently
  on agents-workspace `origin/main` at
  `68688f5bf7463e1ea1c58019cc0707852a2a47e2`. The focused suite now covers 37
  reconnect, reply-provenance, reaction-cleanup, and identity-isolation cases;
  the exact installed NUC package passed all 37 with zero failures.
- Dotfiles repinned that reviewed agents tip in `d74a2b849`; the ten fleet
  commits landed patch-equivalently on dotfiles `origin/main` at
  `a319d244a11cb7d5566a775a054239c4a8abcc5d`.
- The published detached dotfiles tip built and switched generation
  `/nix/store/a85r4w0prkbb8mvmlb90yzsr1yksrpdb-nixos-system-nuc-26.11.20260714.18b9261`.
  All six containers report `Hermes Agent v0.20.5 (2026.8.19)`; all six native
  gateways and all five presence-only companions are active with
  `NRestarts=0`; no `buzz-hermes-*` unit file exists; every companion has
  `BUZZ_ACP_RESPOND_TO=nobody`.
- An identical second switch retained all six container IDs, all six
  `config.yaml` hashes, all six `profile.yaml` hashes, and `NRestarts=0`.
  Generation and rendered state remained byte-identical.
- Generation-specific native Buzz acceptance passed for Amos, Anne, Betty
  ambient meal planning, and Betty's mill-docs mention gate after a greater
  than 90-second observation window: every positive root had exactly one
  same-thread kind-9 final, no interim/tool/activity row, no lingering
  reaction, and no delayed duplicate; unmentioned Betty mill-docs produced no
  reply.
- Generation-specific Scintillate acceptance observed the transient gear from
  `11:25:43Z` until the final at `11:26:06Z`, then no residual reaction or
  duplicate after more than 90 seconds. Literal-mention root `265a4864...`
  produced final `a4889f4e...`, preserving the exact unknown mention in the
  originating thread with one kind-9 final and no duplicate after 111 seconds.
  An earlier probe was correctly excluded because it arrived before Buzz
  reconnected during the deployment restart window.
- A live smart-approval denial exposed one final reaction-add cancellation
  race: the generic 1.5-second typing timeout could abandon a successful Buzz
  child command before the adapter recorded its cleanup target. Regression
  commit `27e46ea` and fix commit `cf15339` now kill and await the cancelled
  child and retain pessimistic cleanup ownership. The pinned exact package
  passed 39 focused tests, including both strict cancellation regressions.
- The cancellation fix landed patch-equivalently on agents-workspace
  `origin/main` at `2ee038c0d25f1a88ab2dcd32b9b74e14fa94eda3`.
  Dotfiles repinned it in `f251eeba4`; dotfiles `origin/main` is
  `a88bd48cd159c37615a25d694c2007df8f5dcaab`.
- The published dotfiles tip built and switched generation
  `/nix/store/4vkj3ljawk1wmw6djdjgnhnwa3l9bvid-nixos-system-nuc-26.11.20260714.18b9261`.
  All six profiles pass bounded live YAML policy assertions, all six containers
  run Hermes v0.20.5 from the patched `1k361ab7...` package, all expected
  gateways and presence companions are active with `NRestarts=0`, every
  companion remains `respond_to=nobody`, and no legacy ACP unit is installed
  or loaded.
- A second identical switch returned zero while preserving all six container
  IDs and all six `config.yaml` hashes. The active generation and package
  remained unchanged.
- Fresh current-generation acceptance passed after the reaction fix. Scintillate
  root `e748301c...` showed `⚙️` only from `12:08:51Z` to `12:09:09Z`, then
  delivered one same-thread final and no residual reaction or duplicate after
  more than 90 seconds. Literal-mention root `92ad8a8e...` preserved exact token
  `@DefinitelyNotABuzzMember_20260824T120835Z-LIT6` in one final with no
  duplicate or reaction after 114 seconds.
- Fresh native Buzz acceptance also passed for Amos, Anne, Betty ambient meal
  planning, and Betty's mill-docs mention gate after more than 100 seconds:
  each positive root produced exactly one same-thread kind-9 final with no
  interim/tool/activity row or lingering reaction; unmentioned Betty
  mill-docs root `faa9a6a7...` remained silent.
- Fresh native smart-approval root `093bffc3...` produced one HIGH control,
  accepted the threaded `/deny`, blocked the command with no execution
  evidence, ended with `active_agents=0`, and had no interim/tool chatter,
  delayed duplicate, or residual reaction over 110 seconds. The one pre-fix
  stale gear was explicitly removed before this probe and has not recurred.
- After macOS was unlocked, Buzz v0.5.18's supported Agents runtime controls
  disabled Finn's `Start on launch` setting and stopped its managed ACP
  instances on both `millers` and `nf-core`. Authoritative profile/runtime UI
  readback shows Finn stopped/offline on both workspaces, no Finn ACP child
  remains, and Mill Docs remains running with start-on-launch enabled on both
  workspaces. Fizz, Pollen, Honey, identity data, and auth data were untouched.
- Finn now has one isolated OpenAI Codex OAuth credential named `finn`, sourced
  by `device_code`; its access and refresh fingerprints differ from
  Scintillate's. Restarting only `hermes-gateway-finn.service` restored the
  native Finn identity with `NRestarts=0`.
- Finn's first authenticated native Buzz root `71feb3b1...` produced exactly one
  same-thread final `5d1a56a2...`, `FINN-FINAL-ONLY-OK 824B`, with no duplicate
  or non-kind-9 row through 236 seconds. The transient `⚙️` reaction was added
  and deleted, leaving no reaction. That turn also exposed an unrelated
  one-time Codex context-threshold explanation as an unthreaded message.
- Regression commit `54b2475` and fix commit
  `badfac91f41cee38eb63a2352caee6243dd8264b` suppress only that gateway notice
  while preserving Hermes's threshold and autoraise behavior. The focused
  rendered-YAML, canonical-module, and Scintillate controls passed on both
  aarch64-darwin and x86_64-linux. Agents-workspace `origin/main` read back
  exactly at `badfac91f41cee38eb63a2352caee6243dd8264b`.
- Dotfiles pin commit `136b344f2817b3b0de06ae56aa400131acd13d71`
  landed exactly on `origin/main` and deployed generation
  `/nix/store/as5wv48xgglwdjzdknfn9v3gml7hlvfw-nixos-system-nuc-26.11.20260714.18b9261`.
  All six containers now run Hermes v0.20.5 from the same
  `g2ynii70...` runtime and `riml1cmk...` package; their configs read back
  `compression.codex_gpt55_autoraise_notice: false` and smart approvals. All
  gateway and presence services are active with `NRestarts=0`, every presence
  companion remains `respond_to=nobody`, and no legacy `buzz-hermes-*` unit is
  installed.
- Post-deploy Finn root `19eaa7e4...` showed `⚙️`, removed it, and delivered
  exactly one same-thread final `bad393a3...`, `FINN-FINAL-ONLY-OK 824B`, after
  17 seconds. The 126-second authoritative readback had no other Finn event,
  no interim/tool/activity row, no unthreaded startup notice, no duplicate,
  and no residual reaction. Fresh Buzz Desktop persisted state still reports
  `start_on_app_launch=false`, `runtime_pid=null`, exit zero, and no Finn PID
  file.
- Beads feature `workspace-2qf.5` is closed in agents-workspace commit
  `37024ad6e4c1d6e98eca4be0985168875d2cff18`, which exactly matches
  `origin/main`; dotfiles runtime pin `136b344f2` exactly matches the deployed
  config, with this closeout worklog as the only later dotfiles change. The
  final dotfiles quality manifest passed Darwin evaluation, hooks, 56 workflow
  tests, agent rules, skill validation, test-confidence audit, and inventory
  drift. Annotated tag `agent-work/workspace-2qf.5` is published at the final
  dotfiles closeout commit.

## Reviews

- Pre-implementation release-plan review found five required corrections:
  enforce policy after overlays, define control-message exceptions, prove all
  package lanes, preserve Bot metadata ownership, and make cutover XOR/rollback
  acceptance executable. The implementation incorporates all five.
- Deployment review found no switch-order blocker and required container-level
  Hermes version readback because the host package is a different profile.
- Release review required permission-denying staged ACP fallback, a live staged
  evaluator, and explicit Discord typing. All three are implemented and the
  corresponding NUC checks pass. The first release-gate re-review passed with
  no P0/P1 findings.
- The reconnect and reaction-cancellation follow-ups were reviewed after their
  test-first fixes. The final release gate is GO for the published and deployed
  NUC release with no P0, P1, or P2 runtime blocker. Its only closeout finding
  was that this worklog still named superseded revisions, corrected above.
- The final Codex-notice fix and its dotfiles pin both received read-only GO
  reviews with no P0, P1, or P2 finding. The pin review independently matched
  its NAR hash and confirmed that neither publication changed Discord behavior.

## Feedback

- The routed `dotfiles-agent-workflow` skill was not installed; this run uses
  the repository-owned `AGENT_WORKFLOW.md` fallback.

## Remaining work

- None. Discord live acceptance is intentionally deferred and outside this
  Buzz-only closeout; all five visible bots satisfy the acceptance contract
  through native Buzz.

## Commits

- Agents workspace: `8bd13f818ae8cf557c9092f2a5b264d8aa2a387b`,
  `464867a4f6c5db36fe73b624a879ef4f6ed79937`, `1f5f827`, `b68a057`,
  `668db3b`, `abd79de`, `2e306ab`, `48d379d`, `0141bc5`, `27e46ea`,
  `cf15339`, `54b2475`, `badfac91`, `37024ad`.
- Dotfiles: `9ac6a819e`, `40cea0200`, `6047e7046`, `887445f76`,
  `38580a2b5`, `b163fcc4e`, `5e9e386ac`, `52358de57`, `c7dfb024e`,
  `d74a2b849`, `f251eeba4`, `136b344f2`.
