# Architecture review — 2026-07-04

Deepening opportunities surfaced by an exploration of the Nix layer and tooling layer.
Vocabulary: **module**, **interface**, **depth** (simple interface hiding substantial
implementation), **shallow** (interface ≈ implementation), **seam**, **leverage**,
**locality**, and the **deletion test** (would deleting it concentrate complexity, or
just move it?).

Existing ADRs (`docs/adr/`) were respected; nothing below contradicts one. #1
*completes* ADR-0004.

## Candidates (ranked)

### 1. Make the Project-local / Global agent skill split structural — **Strong** ⭐ top recommendation

**Files:** `skills/flake.nix` (~700) · `bin/hey.d/skills-catalog.nu` · `bin/hey.d/common.nu:141-178` · `bin/skillkit-sync` · `bin/bootstrap:71-86`

One concept — "put the right skills in the right place" — is smeared across four
languages. Three near-identical verbs (`skills-update` / `skills-sync` / `skills-bump`)
expose Nix plumbing trivia as interface. ADR-0004's invariant (Project-local agent
skills never reach the Global skills target) is enforced only by the
`check-local-skill-leaks` runtime tripwire, not by the generator. `bootstrap`'s
skill-link loop targets `config/agents/skills/`, which no longer exists — silent no-op.

**Deepen:** make skill scope a property of the bundle target in `skills/flake.nix`;
collapse the three verbs into `hey skills-sync [--pin]`; retire the leak-checker once
the invariant is structural.

**Wins:** locality (scoping bugs concentrate in one module) · leverage (one interface,
all consumers) · leak-checker becomes deletable · interface shrinks 3 verbs → 1.

### 2. Decompose the Host Hermes Wiring activation monolith — **Strong**

**Files:** `modules/agents/hermes/default.nix` (548 lines)

Clean interface (`enable, homeDir, settings, honcho, secretReferences`) hiding one
undifferentiated wall: legacy-home migration, skins/plugins/hooks copy, a 50-line
Python YAML config-merge heredoc, a 100-line Codex auth-sync heredoc, ~90 lines of
1Password dotenv materialization. Heredoc Python is unreachable by any test; a
`check-runtime-drift.sh` exists to detect the resulting drift. The sibling Pi module
already shows the target shape (`lib/_activation.nix`, `_settings.nix`,
`_home-files.nix`, `_runtime-wrapper.nix`).

**Deepen:** mirror Pi — extract `lib/_activation.nix`, `lib/_config-merge.py`,
`lib/_codex-auth-sync.py`, `lib/_dotenv-materialize.py`; `default.nix` shrinks to
options + wiring.

**Wins:** interface is the test surface (3 testable .py files) · locality (auth bugs
live in the auth module) · matches repo's own Pi decomposition.

### 3. Modules self-declare platform; delete the central blocklist — **Strong**

**Files:** `default.nix:17-106` (`nixosOnlyFiles` / `nixosOnlyDirs` / `isNixOSOnly`, ~90 lines)

Whether `modules/services/jellyfin.nix` works on Darwin is decided by a 40-entry
string-suffix blocklist far from the module. Adding a NixOS-only service means
remembering to edit the list; forgetting silently breaks the Darwin build. The
knowledge already lives in each module.

**Deepen:** modules self-guard via `mkIf (!isDarwin)` (already threaded through
`_module.args.isDarwin`) or a `meta.platforms` attr the loader reads; loader becomes
"import everything; modules self-guard."

**Wins:** deletion test passes (registry concentrates into modules) · locality ·
adding a service touches one file.

### 4. `mkDarwinHost` seam — mirror `mkHost` for Darwin — **Strong**

**Files:** `flake.nix:315-371` (MacTraitor-Pro) · `flake.nix:372-428` (Seqeratop) · `lib/nixos.nix` (`mkHost`)

Two `darwinSystem` blocks ~95% identical (differ only in `hostName` /
`primaryUser`): same 8-module list, home-manager args, agent-skills jut block.
`nixosConfigurations` even has to subtract the Darwin hosts its abstraction can't
cover. Related: llm-agents re-export list duplicated per-system
(`flake.nix:222-268`, existing TODO); `removeLegacyQmd` + stream-deck lines
duplicated across both host files.

**Deepen:** `lib.my.mkDarwinHost` driven off `hosts/<name>` discovery like
`mapHosts`; both configs become one-liners.

**Wins:** leverage (one interface, N Darwin hosts) · deletes ~110 duplicated flake
lines.

### 5. One agent-rules generator, five consumers — **Strong**

**Files:** `modules/agents/{claude,codex}/default.nix:14-21` · `pi/default.nix:132-139` · `opencode/default.nix:44` · `bin/bootstrap:84`

"Concatenate `config/agents/rules/*.md` into AGENTS.md" implemented three times in
Nix (pi's comment: "Same logic as Claude module for consistency"), once divergently
in opencode (raw symlink), once in bash in `bootstrap` (`cat ...[0-9]*.md`). Change
the selection policy and five call sites drift — opencode already has.

**Deepen:** `lib.my.mkAgentRules { configDir, extraExclude }`; each agent module one
line; bootstrap installs the Nix-built output instead of re-deriving.

**Wins:** leverage (one interface, five call sites) · kills the jscpd landmine ·
opencode rejoins the single source of truth.

### 6. Deletion-test sweep — **Strong** (~30 min)

All pass the deletion test cleanly — nothing concentrates, nothing lost:

| Target | Why |
| --- | --- |
| `darwin.nix` (36) | never imported; AGENTS.md carries a warning-label instead of a delete |
| `bin/rebuild-darwin.sh` (14) | stale fork of `system-rebuild`'s fallback; hardcodes MacTraitor-Pro → wrong host on Seqeratop |
| `debug-p10k.sh` · `fix-p10k.sh` | referenced by nothing |
| `autoresearch.jsonl` · `autoresearch.md` | committed research output, wired to nothing |
| `bootstrap` skill-link loop (`:73-78`) | targets `config/agents/skills/` — path gone; silent no-op |
| `zbench.nu:11-19` fallback | points at `$flake_dir/zsh-bench`, which isn't there; repoint at `benchmarks/zsh-bench` or drop |

Also drop the AGENTS.md warning that exists only to fence off `darwin.nix`.

### 7. Narrow `hey`'s edges — **Worth exploring**

**Files:** `bin/hey.d/remote.nu` (334) · `bin/hey.d/common.nu` `post-rebuild:258-311`, `system-rebuild:191-256`

`hey`'s core (`context`, `system-rebuild`) is genuinely deep; the edges are shallow.
15 near-synonymous nuc verbs (`rebuild-nuc` → `nuc`, `nuc-test` → `nuc dry-activate`,
`deploy-check` → same…), mode lists duplicated four ways, and the riskiest logic
(pi-extension reconcile, betty/scintillate docker logins) lives as 30-line bash
strings inside Nushell where `bin/tests/` can't reach it.

**Deepen:** one `hey nuc <mode>` with a single authoritative mode list; extract bash
blobs to `hey.d/*.sh` files — a shellcheck-able, `--dry-run`-testable seam. Stays
inside ADR-0001: `hey` remains the guarded interface; only internals move.

**Wins:** interface 15 verbs → 2 · seam makes risky bash testable · one mode list,
not four.

### 8. Parameterize `check-runtime-drift.sh` — **Speculative**

**Files:** `modules/agents/pi/check-runtime-drift.sh` (70) · `modules/agents/hermes/check-runtime-drift.sh` (102)

Identical scaffolding (warn/repo_root/symlink checks), but the tails have genuinely
diverged (pi: worktree checks; hermes: `-nt` freshness). Deletion test only
half-passes. Wait for a third consumer before deepening — below that, the leverage
doesn't pay for the indirection.

## Healthy modules (deletion test: genuinely deep, keep)

- `modules/options.nix` `home.file`/`configFile`/`dataFile` aliases — small interface hiding home-manager plumbing
- `lib/modules.nix` `mapModules`/`mapModulesRec'` — one convention powering overlays, packages, modules, hosts
- `hey` core: `context` (common.nu:20-63), `system-rebuild` sudo/agent-mode/archive dance
- Pi's `lib/` decomposition — the model for #2
