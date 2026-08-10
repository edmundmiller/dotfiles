# Worklog: audit-agent-worktrees

Status: blocked

## Objective

Inventory Codex and Herdr worktrees, land every attributable unpublished change on its correct default branch, and preserve active or ambiguous work. Stop when every discovered checkout has a verified disposition and each landed target matches its authoritative remote.

## Decisions

- Inspect patch equivalence, not commit IDs alone.
- Never remove dirty, active, ambiguous, or unverified worktrees.
- Use each repository's existing Git or jj backend and the `done` landing contract.
- Cap generated path and commit lists at five examples plus a remainder count; re-run live checkout inspection because full inventories drift and breach repository size gates.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin arm64.
- Inventory: 100 dotfiles Git worktrees; 56 Codex checkout roots across 7 Git repositories; 4 live Herdr workspace roots using Git or jj.
- Fetched each Git remote before patch comparison. One broad `tnote` fetch failed because a deleted remote tracking ref was requested; `git fetch origin main` succeeded.
- Current root retains only pre-existing user changes: `flake.nix`, `hosts/nuc/_tests/buzz-mill-docs-flue-runtime.nix`, `hosts/nuc/default.nix`, and `hosts/nuc/secrets/secrets.nix`.

## Reviews

- Primary review: `hey agent-review plan --active-model-family openai --worklog .agents/worklogs/audit-agent-worktrees.md` failed: `RUNTIME: Authentication required`. Alternate review: `--active-model-family grok --reviewer opencode` started but timed out after 300 seconds before yielding a review result. No approved plan gate exists.

## Feedback

None.

## Remaining work

- Authenticate the independent plan-review runtime, then review and land each `BLOCKED` committed patch set in the manifest below.
- Re-run focused checks and `done` verification for every landed repository.
- Remove only clean, inactive, fully landed worktrees after provenance checks.

## Per-checkout manifest

# Worktree audit evidence

Generated 2026-08-01. Remote refs fetched before comparison. No worktree was altered or removed.

## Git checkouts

### /Users/emiller/.codex/worktrees/3b4fccf0-749d-4d2a-a317-7479b3b6fa9a/agents-workspace

- Repository: `git@github.com:edmundmiller/agents-workspace.git`
- Target: `origin/main`
- Branch: `codex/workspace-rtl-2-tracker`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 7778ed7ab33a7bd5e7eb9946fa408c6c62ba60b9 chore(beads): record Betty deploy freeze; 6752d5933c490e406ce190c9729fce89cd2b54d6 chore(beads): record Betty merged tick proof; b1b1fc6287613c572cd865e6fd24228960be5e94 chore(beads): verify Betty runtime prerequisites

### /Users/emiller/.codex/worktrees/45b063d8-ec2d-47fb-bde2-ebfb229e6b35/agents-workspace

- Repository: `git@github.com:edmundmiller/agents-workspace.git`
- Target: `origin/main`
- Branch: `codex/amos-model-routing`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 6610fdbcc3c9f68f60ec0e2ace9b650a649bb762 chore(beads): record Amos deployment freeze; 9af733ef00b3aa99aab4eb1bbacad4882dc3e145 chore(beads): record Amos natural fallback failure

### /Users/emiller/.codex/worktrees/70efe10d-54a4-44b5-92cc-79688e031e58/agents-workspace

- Repository: `git@github.com:edmundmiller/agents-workspace.git`
- Target: `origin/main`
- Branch: `codex/workspace-rtl-1-close`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: ee2d0cae13915b74c40c8529ff7df0aff65ee68b chore(cron): close Amos executor recovery; 4aa2757aa5e71032beb189197cc52872d8ba754d docs(cron): correct Amos generation evidence; 2f0f49cc0f66f53206bcedf54cfc2ff08a5524b8 docs(cron): record final Amos cleanup branch

### /Users/emiller/.codex/worktrees/8c16dda7-7b35-41b1-bd76-9fdf951809f3/agents-workspace

- Repository: `git@github.com:edmundmiller/agents-workspace.git`
- Target: `origin/main`
- Branch: `codex/workspace-i1q-tracker`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: bf032054430ccdf686ad3e3c5b55f215452d9829 chore(beads): checkpoint cron warning fix; bd8f31556fc7eaea72c0b722aee9086ffdadfd2c chore(beads): clarify frozen deploy state

### /Users/emiller/.codex/worktrees/beads-prek-guard/agents-workspace

- Repository: `git@github.com:edmundmiller/agents-workspace.git`
- Target: `origin/main`
- Branch: `codex/beads-prek-guard`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 8f11aa22c6c45e0315ab0b9f065607679a5b0dd4 chore(beads): track issue-state hook; d5b2e658953304edaaa4da827c234073dbabcf95 feat(beads): block unrecorded issue state

### /Users/emiller/.codex/worktrees/feedback-fix-loop/agents-workspace

- Repository: `git@github.com:edmundmiller/agents-workspace.git`
- Target: `origin/main`
- Branch: `codex/feedback-fix-loop`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/ff3aa9dc-5514-4998-8efa-946882b0a4fb/agents-workspace

- Repository: `git@github.com:edmundmiller/agents-workspace.git`
- Target: `origin/main`
- Branch: `codex/workspace-rtl-3-status`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 3cb89e394854dce7483d3828314951d7eaf640d5 chore(beads): refresh Scintillate deploy request

### /Users/emiller/.codex/worktrees/144d62b4-e6c5-48fe-9664-5dc1f4d13f33/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: M 01_Tasks/check-cloudflare-logs-for-flue-agent-failures.md; M 04_Resources/.last-update.json; M 04_Resources/AI-Prompts/index.md; M 04_Resources/Academic-Papers/index.md; M 04_Resources/Books/adhd-productivity-manual-tuckman/images/index.md; ... (246 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/2867/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `codex/bump-flue-beta9`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/2ad170d0-3bc7-4f4c-840e-4336e486bfc1/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: D 01_Tasks/bot-1-hook-openclaw-up-to-linear.md; D 01_Tasks/bot-10-make-sure-the-agent-can-connect-to-the-notes.md; D 01_Tasks/bot-14-will-vercel-chat-do-a-better-job-of-integrating.md; D 01_Tasks/bot-15-every-single-chat-in-the-claw-starts-it-just-says-it-s-going-to-pull-the-.md; D 01_Tasks/bot-17-give-openclaw-and-agents-access-to-healthchecks.md; ... (621 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/2e613603-18b3-4270-afda-fe55a9477015/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: M 00_Inbox/Articles/X/2026-05-21-001tmf-blatant-why-ai-powered-biologics-design-campaign-agent-multi-agent-orches.md; M 00_Inbox/Articles/X/2026-05-29-pi-coding-agent.md; M "00_Inbox/Calendar/Avoma/2026-03-02 - Sarek Dev Meeting.md"; M "00_Inbox/Calendar/Avoma/2026-03-09 - Sarek Dev Meeting.md"; M "00_Inbox/Calendar/Avoma/2026-03-16 - Sarek Dev Meeting.md"; ... (1221 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/3ca0ef6b-fb0e-404f-b1d6-ef7c7e66f5c2/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: BLOCKED: committed patches plus uncommitted changes
- Unlanded commits: 1bb4928782fdcb26dfeef26a6d36ecf2a9ea6925 fix(qmd): repair repo-local index setup; 48a96d53426429708ff8454ea62680106798b0e9 test(qmd): specify automatic refresh behavior; 87597ded355e4722701be73df0c0f60d1dacf13b fix(qmd): refresh before vault search; 8d6af32e0d8e47778a1cbf6106962caedacf8fdc test(qmd): clean launcher fixtures; 25488ffaf26fdd6a1bc4b98707adf2dbda9c39f7 test(tasknotes): align regressions with v0.3; ... (1 more; re-run live checkout inspection)
- Dirty paths: M 01_Tasks/a-ask-ezra-how-he-feels-post-baptism.md; M 01_Tasks/buy-custom-concert-earplugs.md; M 01_Tasks/check-cloudflare-logs-for-flue-agent-failures.md; M 04_Resources/.last-update.json; M 04_Resources/AI-Prompts/index.md; ... (249 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/4bb0/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `codex/qmd-worktree-seeding`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 788057a7d5ea2c2d8c5ba5c31918046d7063a8ea fix(qmd): seed indexes in linked worktrees; ae4403e8b0426bd993bc636582234411b89e1a83 test(qmd): capture jj workspace seeding gap; e578142b6de125fdf4319c00555910c3f9351560 fix(qmd): seed jj workspaces from default root; 0564ee46dbbf6c6f4cc0674e85bee7e718f1c58e test(qmd): reuse primary workspace fixture

### /Users/emiller/.codex/worktrees/53946671-3eb7-4a36-8103-245cda2bb5cd/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `codex/flue-2-migration`
- Disposition: BLOCKED: committed patches plus uncommitted changes
- Unlanded commits: a73810e8536194f149b5933d0591b4d282ac586e feat(flue): migrate agents to Flue 2; fd93f521153338ea9f3cdf45ac781d3ea280844d test(flue): add production agent smoke runner; 03bf3a431d88f1455bade2c6b1b1d0e45eb4135d docs(flue): document the Flue 2 runtime
- Dirty paths: M 01_Tasks/Timesheet.md; D 01_Tasks/bot-1-hook-openclaw-up-to-linear.md; D 01_Tasks/bot-10-make-sure-the-agent-can-connect-to-the-notes.md; D 01_Tasks/bot-14-will-vercel-chat-do-a-better-job-of-integrating.md; D 01_Tasks/bot-15-every-single-chat-in-the-claw-starts-it-just-says-it-s-going-to-pull-the-.md; ... (635 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/5c19ee8d-a8f9-4918-9fbf-044225ffaf84/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `codex/workout-agent-v1`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: M .codex/hooks.json; M .obsidian/app.json; M .tn/undo-stack.json; D 00_Inbox/Daily/2026-01-19.md; D 00_Inbox/Daily/2026-01-21.md; ... (433 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/73d9/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: ?? 04_Resources/large_tool_results/

### /Users/emiller/.codex/worktrees/7c0d/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: M .agents/skills/analyze-logs/SKILL.md; M .flue/evlog.ts; M .gitignore; M package.json; M pnpm-lock.yaml; ... (2 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/c1ae0dbd-72c6-4e08-8c54-114af4ac5cb0/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: M .beads/issues.jsonl; M .flue/cloudflare.ts; M 04_Resources/.last-update.json; M 04_Resources/Academic-Papers/9A9B2EA9-9148-4115-BC0D-6C2CF8A6C411-Tae-meeting36.md; M "04_Resources/Academic-Papers/ADHD and Sex Hormones in FemalesA Systematic Review.md"; ... (49 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/ca0e14ae-70c0-435f-8b5b-f76123c1a2d1/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: M .codex/hooks.json; M .obsidian/app.json; M .tn/undo-stack.json; D 00_Inbox/Daily/2026-01-19.md; D 00_Inbox/Daily/2026-01-21.md; ... (433 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/cf79/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `codex/fix-snipd-trigger-payload`
- Disposition: BLOCKED: committed patches plus uncommitted changes
- Unlanded commits: 1bb4928782fdcb26dfeef26a6d36ecf2a9ea6925 fix(qmd): repair repo-local index setup; 48a96d53426429708ff8454ea62680106798b0e9 test(qmd): specify automatic refresh behavior; 87597ded355e4722701be73df0c0f60d1dacf13b fix(qmd): refresh before vault search; 8d6af32e0d8e47778a1cbf6106962caedacf8fdc test(qmd): clean launcher fixtures; 25488ffaf26fdd6a1bc4b98707adf2dbda9c39f7 test(tasknotes): align regressions with v0.3; ... (3 more; re-run live checkout inspection)
- Dirty paths: ?? 04_Resources/large_tool_results/

### /Users/emiller/.codex/worktrees/d57c4037-2f68-4523-85b8-f972de593b27/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: BLOCKED: committed patches plus uncommitted changes
- Unlanded commits: b45271e407bb61b2678172f5ddd93581e5875f1f docs(openwiki): ingest git-repo-1; ec3342aae83eb71dc15319977ad1a1925743a925 docs(openwiki): ingest x-1; f772bbcdacf3fc0b3c1c8db45622c831a1ebea4b feat(fitness): prefer compound-first strength sessions; 8a6493f679162b697b1902dc8f6e1d23b7bc70d6 refactor(fitness): alternate low-fatigue strength sessions
- Dirty paths: M 01_Tasks/check-cloudflare-logs-for-flue-agent-failures.md; M 07_Metadata/Reports/cloudflare-flue-morning-check.md; M test/fitness-weekly-agent.test.ts; ?? 01_Tasks/repair-august-1-personal-workflows-failures.md

### /Users/emiller/.codex/worktrees/e03961c3-f7cb-4cac-9aa2-b4317e3f9ded/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: M .tn/undo-stack.json; D 00_Inbox/Daily/2026-03-17.md; D 00_Inbox/Daily/2026-03-18.md; D 00_Inbox/Daily/2026-03-19.md; D 00_Inbox/Daily/2026-03-20.md; ... (428 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/ef7cd3f7-22d4-4a1d-bbdd-c13445cdd5e7/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/flue-evlog-runtime

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `codex/flue-evlog-runtime`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 9f3d3ef19bc57833205b047823fa753f54cec9aa fix(flue): use Cloudflare-safe evlog runtime; 0423ca8f5a789f4f0d4336f563ad71a2890258e7 test(flue): capture evlog privacy regressions; a2a12f52dc9a5fbe66bebffb94c559b55272f7f6 fix(flue): keep evlog events privacy-safe

### /Users/emiller/.codex/worktrees/lila-communication-debrief-20260727

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `codex/lila-communication-debrief-20260727`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: ?? 04_Resources/large_tool_results/

### /Users/emiller/.codex/worktrees/workout-hevy/obsidian-vault

- Repository: `git@github.com:edmundmiller/claude-vault.git`
- Target: `origin/main`
- Branch: `codex/workout-agent-hevy-write`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: ?? 04_Resources/large_tool_results/

### /Users/emiller/.codex/worktrees/256c/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/herdr-codex-jj`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/2c371ca1-8ca4-4645-9ad8-09d9f8e5c045/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `fix/ha-ecobee-manual-override-20260728`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/2c9117dc-6a76-4f59-b1a6-dafda2ffd781/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/2d7319cf-4c62-46f0-bdcc-ac31a79d20b7/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/amos-linear-auth`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: f0d2b439953dbf1770e408707dc1749cd87f04e8 test(hermes): cover Amos Linear credential source; 2aa9e94a7b22ffc3393a1df395b47fcfe1720254 fix(hermes): repair Amos Linear authentication; a071044876ce874d4fa537b749b94b420a8f90f0 docs(worklog): record Amos Linear repair evidence

### /Users/emiller/.codex/worktrees/7046/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/77453a04-d599-4f5a-b37f-2cc15f8bbc16/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: M flake.nix; M hosts/nuc/default.nix; M hosts/nuc/secrets/secrets.nix; M modules/services/hass/\_domains/sleep/default.nix; M modules/services/hass/\_tests/eval-automations.nix; ... (1 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/802874fd-2a1f-430c-bce6-a6ca7e54a611/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/94f9/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/omp-pi-review-loop`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/9503b982-ed2e-4399-8c22-32780704ac5f/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: M .beads/issues.jsonl; M hosts/nuc/\_tests/hermes-cron-executors.nix; M hosts/nuc/default.nix; M hosts/nuc/secrets/ha-hermes-token.age; M modules/shell/mo/default.nix; ... (3 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/be521888-4dad-4098-9d5b-f88c8e74ee9f/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/openwiki-discord-source`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: M .beads/issues.jsonl; ?? .github/workflows/openwiki-update.yml

### /Users/emiller/.codex/worktrees/cf130184-7fbc-4164-ad25-1d950c693c6d/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/d718f71c-6e91-44c8-84c1-19fbb69581ac/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: M config/herdr/config.toml; M modules/shell/herdr/default.nix; M overlays/herdr/default.nix; M overlays/herdr/package-harness.json; M overlays/herdr/patches/0008-ignore-zero-terminal-resize.patch; ... (2 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/feedback-fix-loop/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/feedback-fix-loop`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/qmd-herdr-seeding/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/qmd-herdr-seeding`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: a4b460bff3e659d1b2a35be3d4d5357b94f3e68e test(herdr): capture qmd seeding order; fa2dc6d27c2dc7f661b82c013f47d60acb5f8818 fix(herdr): seed qmd before Codex starts

### /Users/emiller/.codex/worktrees/zele-readonly-guard/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/zele-readonly-guard`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: bab0099139b77587a9aa458bdf9e78b6600b6b2e test(zele): capture outbound mail regression; 761e9908973346100f1aaa5e1c68600191dbd3d6 fix(zele): disable outbound mail; 86d53a8e63998e2510f03729935cae5496c205aa docs(zele): record read-only verification

### /Users/emiller/.codex/worktrees/448dbcbd-763c-4a5d-9ea4-c38dbb51b1a8/edmundmiller-dev

- Repository: `git@github.com:edmundmiller/edmundmiller.dev.git`
- Target: `origin/main`
- Branch: `codex/write-simply-vale`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: eb758a45a509dd6d41a8aef5e02d84b57577c49f feat: add Write Simply sentence lint; 775b2dce963c7d13c98fc47c1ebe97acfa13cc2f feat: suggest plainer words; 6330374c2c149ddc1a766374a504052f706bc373 feat: flag needless prose; 51d11fef9e6687fe2e038ef6af0fd31b63d2fa3e feat: flag complex sentences; 41a5a494aac8cd3746096eb4fad2903b8a77e85e test: capture Vale count formatting bug; ... (75 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/96965dbf-5c1c-416b-8cf8-4ffe38d5e0b9/macro-diff-refinement

- Repository: `git@github.com:edmundmiller/macro-diff-refinement.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/0185daec-b90c-4917-93c2-79d62f2a8fff/tnote

- Repository: `git@github.com:edmundmiller/tnote.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/2f2e/tnote

- Repository: `git@github.com:edmundmiller/tnote.git`
- Target: `origin/main`
- Branch: `codex/effect4-cli-migration`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/acb963f1-c21c-408c-a9e8-5d249e68bb30/tnote

- Repository: `git@github.com:edmundmiller/tnote.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/c5cc28ba-6241-4abd-80c8-5fc020eafed7/tnote

- Repository: `git@github.com:edmundmiller/tnote.git`
- Target: `origin/main`
- Branch: `codex/evlog-agent-diagnostics`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/tnote-schedule-memory-backport

- Repository: `git@github.com:edmundmiller/tnote.git`
- Target: `origin/main`
- Branch: `codex/tnote-schedule-memory-backport`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 0606b6d6a7a939f9d98521f9daa59820875a00cd fix: keep mdbase cache writable after flush; 3dc5771991322a518c27be09efb76eb79f84a2cb fix(tn): bypass SQL.js cache in deployed TaskStore

### /Users/emiller/.codex/worktrees/0ee8578a-c102-44cb-8853-0c3297172279/mill-docs

- Repository: `https://millers.communities.buzz.xyz/git/fdb266e13b8a216bcb47132c5451fa4cac6b70730bd6d9952b9609362cc84d4c/mill-docs`
- Target: `origin/main`
- Branch: `codex/flue-buzz-channel`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/21f9/mill-docs

- Repository: `https://millers.communities.buzz.xyz/git/fdb266e13b8a216bcb47132c5451fa4cac6b70730bd6d9952b9609362cc84d4c/mill-docs`
- Target: `origin/main`
- Branch: `codex/analyze-monica-sleep-and-fights`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 31feb9c9dd6ce7a09d0f51de852df7c752ff56ec Document Home Assistant sleep history findings

### /Users/emiller/.codex/worktrees/24f990c5-bc9f-4990-bb68-fce78708adb0/mill-docs

- Repository: `https://millers.communities.buzz.xyz/git/fdb266e13b8a216bcb47132c5451fa4cac6b70730bd6d9952b9609362cc84d4c/mill-docs`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes; no unique committed patch
- Dirty paths: M agents/docs/adr/2026-07-03-house-search-market-monitor.md; M agents/src/agents/board-meeting.ts; M agents/src/workflow-support/model-workflow.ts; M agents/src/workflow-support/scheduled-workflows.ts; M agents/src/workflows/daily-briefing.ts; ... (20 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/392a428e-96cd-4119-b676-09ff272e8df8/mill-docs

- Repository: `https://millers.communities.buzz.xyz/git/fdb266e13b8a216bcb47132c5451fa4cac6b70730bd6d9952b9609362cc84d4c/mill-docs`
- Target: `origin/main`
- Branch: `codex/nuc-signed-reconcile`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/48826e2f-9f37-4d1e-9452-8013c640766a/mill-docs

- Repository: `https://millers.communities.buzz.xyz/git/fdb266e13b8a216bcb47132c5451fa4cac6b70730bd6d9952b9609362cc84d4c/mill-docs`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/588b/mill-docs

- Repository: `https://millers.communities.buzz.xyz/git/fdb266e13b8a216bcb47132c5451fa4cac6b70730bd6d9952b9609362cc84d4c/mill-docs`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.codex/worktrees/89cc2fac-b7a2-470e-802d-08e469a02d81/mill-docs

- Repository: `https://millers.communities.buzz.xyz/git/fdb266e13b8a216bcb47132c5451fa4cac6b70730bd6d9952b9609362cc84d4c/mill-docs`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: BLOCKED: committed patches plus uncommitted changes
- Unlanded commits: 1781e6ac60c095875e37ac9a669d1c55fa690ed7 feat(agents): migrate Flue runtime to v2
- Dirty paths: M "03_Resources/Granola/2025-01-28 Board Meeting-2026-01-29.md"; M "03_Resources/Granola/2025-06-23 - meeting-about-research - not_okTU4k7R208nL0.md"; M "03_Resources/Granola/2025-06-30 - meeting-about-research - not_afGwfH83aavwJ2.md"; M "03_Resources/Granola/2025-07-07 - meeting-about-research - not_9YWtxOurDIsRCe.md"; M "03_Resources/Granola/2025-07-11 - phd-writing-process-and-adhd-strategy-planning - not_UHjnYxVnztzsKl.md"; ... (286 more; re-run live checkout inspection)

### /Users/emiller/.codex/worktrees/90da79b7-86a5-404d-9c51-59ceb5481d88/mill-docs

- Repository: `https://millers.communities.buzz.xyz/git/fdb266e13b8a216bcb47132c5451fa4cac6b70730bd6d9952b9609362cc84d4c/mill-docs`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/src/personal/mill-docs

- Repository: `https://millers.communities.buzz.xyz/git/fdb266e13b8a216bcb47132c5451fa4cac6b70730bd6d9952b9609362cc84d4c/mill-docs`
- Target: `origin/main`
- Branch: `wip/mill-docs-main-preserve-20260731`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 52874c1e4c77d8ced2c87ae5a1ec6833fb9de4af chore(wip): preserve local MillDocs edits

## Additional dotfiles worktrees

### /Users/emiller/.config/dotfiles

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `wip/main-preserve-20260730-ma-landing`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 993272d910771116607874ec2a6659aef66b4f36 fix(herdr): launch OMP and root Hunk in checkout; d30a9977aa003a3add6ae12171589810d13df53d docs(herdr): align agent workflow with OMP bootstrap
- Dirty paths: M flake.nix; A hosts/nuc/\_tests/buzz-mill-docs-flue-runtime.nix; M hosts/nuc/default.nix; M hosts/nuc/secrets/secrets.nix; ?? .agents/worklogs/audit-agent-worktrees.md

### /Users/emiller/.config/dotfiles-agent-worktree-0001

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/fix-qa-changed`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: ?? .pi/active.lock

### /Users/emiller/.config/dotfiles-agent-worktree-0002

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/quality-review`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: ?? .pi/active.lock

### /Users/emiller/.config/dotfiles-agent-worktree-0003

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/efficiency-review`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: ?? .pi/active.lock

### /Users/emiller/.config/dotfiles-agent-worktree-0004

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/reuse-review`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: ?? .pi/active.lock

### /Users/emiller/.config/dotfiles-agent-worktree-0005

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/quality-review-2`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles-agent-worktree-0006

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/efficiency-review-2`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles-agent-worktree-0007

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/reuse-review-3`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles-agent-worktree-0008

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/quality-review-3`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: c26d768c7f6a97d57a27ed825162048284c64094 Override pi package to 0.75.5

### /Users/emiller/.config/dotfiles-agent-worktree-0009

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/efficiency-rerun`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: c26d768c7f6a97d57a27ed825162048284c64094 Override pi package to 0.75.5

### /Users/emiller/.config/dotfiles-agent-worktree-0010

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/reuse-rerun`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: c26d768c7f6a97d57a27ed825162048284c64094 Override pi package to 0.75.5

### /Users/emiller/.config/dotfiles-pi-20260401-191320

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `dotfiles-pi-20260401-191320`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles-test-cockpit

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `dotfiles-test-cockpit`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles-worktrees/dotfiles-pi-20260504-052956791-x4qok

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: M modules/services/hass/default.nix

### /Users/emiller/.config/dotfiles-worktrees/dotfiles-pi-20260504-053000547-gf5f6

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: M bin/tnote-capture

### /Users/emiller/.config/dotfiles-worktrees/dotfiles-pi-20260504-053005346-j2w72

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: M hosts/nuc/default.nix; ?? modules/services/timew_sync.nix

### /Users/emiller/.config/dotfiles.add-compliance-check-rule

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/add-compliance-check-rule`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles.add-via-negativa

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/add-via-negativa`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles.agent-traces-datalake

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `agent-traces-datalake`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 131982c5fa10334f4ae680aad41a52b94983d185 feat(agent-traces): ingest sessions into R2 Iceberg; 2ef51fd4d7a5a6b860dc4451fce4ebb76fab0d92 feat(agents): schedule Iceberg ingestion and reuse it; b70cef1a6a047e8bc6174aaf945733c16fc901e9 docs(agent-traces): record Iceberg ingest verification evidence; 87907a754b27179848b4394c7eb504cf1b841ec2 fix(agent-traces): batch Iceberg appends during ingest; 4b53cc48308ebfdf46695ab8f1426b9911c40599 fix(agent-traces): tolerate surrogate characters in trajectories; ... (1 more; re-run live checkout inspection)
- Dirty paths: ?? implementation-notes.html

### /Users/emiller/.config/dotfiles.amos-cron-executor

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/amos-cron-cleanup-final`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles.amos-model-routing

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/amos-model-routing-deploy`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 8e2cb8b0f59dc1f408b9d6cbd40d24830e9321b2 chore(nuc): deploy Amos model routing

### /Users/emiller/.config/dotfiles.bd-capture-core

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `bd-capture-core`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: M .envrc

### /Users/emiller/.config/dotfiles.bd-capture-features

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `bd-capture-features`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: M .envrc

### /Users/emiller/.config/dotfiles.bd-capture-ui

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `bd-capture-ui`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: M .envrc

### /Users/emiller/.config/dotfiles.betty-cron-executor

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/betty-cron-executor-rebased`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles.browser-control

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/browser-control-skill`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles.buzz-codex-nuc

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `buzz-codex-nuc`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: M .beads/issues.jsonl

### /Users/emiller/.config/dotfiles.cleanup-jjui-config

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `cleanup-jjui-config`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: M .envrc

### /Users/emiller/.config/dotfiles.cron-integration

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/cron-integration`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles.cron-warning

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/hermes-cron-warning`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 52d6508acdb077a18d38b691921842875f6f6c73 fix(hermes): report timer-driven cron health

### /Users/emiller/.config/dotfiles.enable-opencode-module

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: R config/opencode/INSTRUCTIONS.md -> config/opencode/GLOBAL_INSTRUCTIONS.md; ?? .pi/

### /Users/emiller/.config/dotfiles.hca-deploy

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/hermes-silent-evidence-deploy`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles.herdr-worktree-events

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/herdr-worktree-events`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: e9553cba68a3711cd7f3e92fe36ea41a0422dc01 test(herdr): capture 0.7.5 CLI regression; c47a17bc199864dabb26e943ec03d13b43f93aa2 fix(herdr): teach the 0.7.5 agent CLI; 1315eeb0651e2c4c41cc0f77bb3a8939db0a1e20 docs(herdr): map the worktree event lifecycle; a5271fe56b42322a14815f08a46b82014d030e19 chore(agents): record Herdr event migration

### /Users/emiller/.config/dotfiles.hermes-local

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `feat/hermes-local`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: b87fe7ede0145abd277b393648d8849040396663 feat(hermes): manage laptop runtime with nix; 39498390432c880f99e206c6d68521eb567a95ad chore(agents): record Hermes rollout; 1d6f56f29f6d0a3b1acac64ca3be26c1b5bf094c chore(agents): finalize Hermes worklog

### /Users/emiller/.config/dotfiles.openwiki-relative-raw-paths

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `fix/openwiki-relative-raw-paths`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles.radar-blogwatcher

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/radar-blogwatcher-cli`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles.radar-signals

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/radar-signals-deploy`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles.remove-jut-skill

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `remove-jut-skill-20260724`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 797d991a9a9753ecff91a80a635c4cc0ede5f715 Update Herdr routing and crash diagnostics; f8de2323200987b0780424177e0a5ac00b5c2c06 test(pi-hunk): capture removed Herdr helper regression; 457e50dff17dc2a17299ae661164c946a4c46276 test(herdr): capture duplicate writable keybindings; 8f723bca82b9ec5205405cb169fd1fee8c0b4b73 chore(herdr): bump to 0.7.5; 89f65a807ca899af78b5f09ab0b5f39b28fe4a80 feat(herdr): adopt 0.7.5 agent automation; ... (2 more; re-run live checkout inspection)

### /Users/emiller/.config/dotfiles.scintillate-cron-executor

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/scintillate-cron-executor-next-deploy`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: b714179f5ad1e0caf0ec91f317a15acafe5e81e1 docs(cron): refresh Scintillate next-deploy handoff

### /Users/emiller/.config/dotfiles.scintillate-cron-sync

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/scintillate-cron-sync-deploy`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 6186124f4d394dc7c90226624aaf6f3f237c817a chore(nuc): deploy declarative Hermes cron sync

### /Users/emiller/.config/dotfiles.sol-terra-instructions

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/sol-terra-instruction-audit`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 559b3d0173907b9497144151af8250fb3246e32c feat(agents): validate portable instructions; 1ffa0437f33175b2505ee057a316cb37a79fe083 test(agents): capture active-root finish regression; 1a958e5c39aaf9327b028be6d0a33278b97b4257 fix(agents): run finish gates in active worktree; b7cbb8d196195feb61113f4b793d0dbed1ed3622 chore(agents): record instruction audit evidence; 8b4367a5e6936d47505da4a044a5fbcfa8550238 chore(agents): complete instruction audit

### /Users/emiller/.config/dotfiles.task-hermes-cron-audit-fixes

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `task-hermes-cron-audit-fixes`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles.test

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `test`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles.zele-schema-idempotent

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/zele-schema-idempotent`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/dotfiles/.pi/worktrees/pr-4306-renovate-github-actions

- Repository: `git@github.com:edmundmiller/dotfiles.git` metadata only; commit history is foreign/ambiguous.
- Target: unresolved; must not be `origin/main`.
- Branch: `DETACHED`
- Disposition: QUARANTINE: its tip `7ba32aa4956…` is a Renovate `docker/setup-qemu-action` commit and its ancestry begins outside dotfiles. Resolve the original PR repository/base before any landing or cleanup.
- Unlanded commits: 5b52c2d2b3d19e97df7b9fc6dedd1e09559cb94a Initial commit; 90fb94bb4d0cb0b78cbd44b8283668565c745d26 First commit. Basic linting subcommand in place.; 338f4509513014769c5b255757ca2f5d70c86d28 Made readme example a little nicer.; 8c1385915f09fd056b0a614cf7ec9d1f86f4f66a Change some required / warn files; 7b9ca7cc0e56ac4eeacbdac7819792b4978d0b6a Remove redundant entry for nextflow.config; ... (10780 more; re-run live checkout inspection)

### /Users/emiller/.config/worktrees/\_reserve-wiahld

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `_reserve/wiahld`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/worktrees/crisp-pants-hunt-5s9

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `emdash/feat-amp-tokens-day-5s9`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/worktrees/dotfiles/claude-main-20250831-142443

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `claude-main-20250831-142443`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/worktrees/dotfiles/tmux-cmux-concept

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `concept/tmux-cmux-strategy`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: b9d6d1a0657ca3cc50e2ef2ffc845c84a50dc235 tmux: add cmux-inspired workspace profile and tmx bootstrap

### /Users/emiller/.config/worktrees/fix-gha-ci-repo-9j5

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `emdash/fix-gha-ci-repo-9j5`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.config/worktrees/shimmer-merge

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 4cb3cbae71f9f05904f5ffd3ab7c2d7a5dc87085 feat: route telegram to shimmer

### /Users/emiller/.config/worktrees/sunny-jokes-teach-91o

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `emdash/feat-tty-91o`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/demo-herdr-layout-20260525113542

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `demo-herdr-layout-20260525113542`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/fix-treefmt-hook

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `fix-treefmt-hook`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/good-night

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `goodnight-adr-impl`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/herdr-hacks

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `herdr-hacks`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/herdr-hacks-agent-worktree-0001

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/explore-herdr`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: d37c9b52b9a4afcfdb1e1e70a6ea6b0467c1202a feat(herdr): package helper scripts in overlay; a79b54be3446c1401c1997f58f05dae347281a8a chore(beads): sync issues; 1b71b147d978f088911c10522a9c42a58f6015a8 refactor(herdr): patch helpers into binary
- Dirty paths: ?? .pi/active.lock

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/herdr-integrations

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `herdr-integrations`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/herdr-reviews

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `herdr-reviews`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/herdr-reviews-agent-worktree-0001

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/reuse-review-2`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 5b1366d1e23afd1e909843fc6d854bbc9e2be5f1 Make prr select review tool
- Dirty paths: ?? .pi/active.lock

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/herdr-reviews-agent-worktree-0002

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/quality-review-4`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 5b1366d1e23afd1e909843fc6d854bbc9e2be5f1 Make prr select review tool
- Dirty paths: ?? .pi/active.lock

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/herdr-reviews-agent-worktree-0003

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/efficiency-review-3`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 5b1366d1e23afd1e909843fc6d854bbc9e2be5f1 Make prr select review tool
- Dirty paths: ?? .pi/active.lock

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/oxfmt

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `oxfmt`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/test-herdr-hook-python-20260525193355

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `test-herdr-hook-python-20260525193355`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/test-herdr-hook-uvpath-20260525193858

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `test-herdr-hook-uvpath-20260525193858`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/testing1

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `testing1`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-brave-cloud-e8c8

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `worktree/brave-cloud-e8c8`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: cadccc88c75ec83b2b54b29934fd356ab1e5f54c feat(agents): enforce OMP completion checks; 32a907bc066ba0762d4e6c8f4ebe623bc88f6376 fix(agents): keep completion gate repo-local; bbc2131a886321ebb80f3934a23de35908734bb3 fix(agents): load completion gate as project hook

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-brave-meadow-3368

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `worktree/brave-meadow-3368`
- Disposition: PRESERVE: uncommitted changes
- Dirty paths: M hosts/nuc/secrets/.wrangler/cache/wrangler-account.json; ?? packages/pi-packages/pi-xurl/index.test.ts

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-brave-meadow-b368

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `worktree/brave-meadow-b368`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: ae2fcbcc630b631f5e2c09b7c71cd4e5270fe44e feat(skills): add testing framework skills; 85253ca155df13280859061fbefb7c3d66ddef6a chore: sync beads; d91b2a335cca8c0d5012c3bdbc592b269ded565e docs(skills): tighten testing skill triggers; 111152bb9897fa49d9f91a2ccccc2fc6aae79155 docs(skills): add testing skill resources; 551d0430079bcf81cd62cb41a2b0e57802eabb86 chore: sync beads; ... (5 more; re-run live checkout inspection)

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-clear-harbor-9a62

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `worktree/clear-harbor-9a62`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-clear-meadow-ceea

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `worktree/clear-meadow-ceea`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-clear-river-bf42

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `worktree/clear-river-bf42`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-clear-stone-37f2

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `worktree/clear-stone-37f2`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-lucky-harbor-1924

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `worktree/lucky-harbor-1924`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-lucky-river-e944

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `worktree/lucky-river-e944`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-rapid-valley-34fe

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `worktree/rapid-valley-34fe`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-silver-harbor-45a7

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `worktree/silver-harbor-45a7`
- Disposition: BLOCKED: clean committed patches absent from default branch
- Unlanded commits: 4ebc914b57c093d3e92c7682976a5f82990a8bd6 feat(omp): install shared agent rules; 33ecfb819d35a8e78b71e8d836b6e15930453913 chore(beads): sync issues

### /Users/emiller/.paseo/worktrees/19x967uh/serene-blowfish

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `serene-blowfish`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.superset/worktrees/dotfiles/agents-linters-agent-worktree-0001

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `side-agent/beads-loop-rules`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/.superset/worktrees/dotfiles/boom-cement

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `boom-cement`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/Library/Application Support/Muxy/worktree-checkouts/CB7B4B01-D8BB-44E7-8DE0-12A2FF4EE36A/muxy

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `muxy`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /Users/emiller/orca/workspaces/dotfiles/hermes-paseo

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /private/tmp/dotfiles-buzz-hermes-community

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/buzz-hermes-community`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /private/tmp/dotfiles-ha-bedtime-lights-20260726

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `DETACHED`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

### /private/tmp/dotfiles-vault-dirt-monitor

- Repository: `git@github.com:edmundmiller/dotfiles.git`
- Target: `origin/main`
- Branch: `codex/vault-dirt-monitor`
- Disposition: LANDed-equivalent-or-clean: candidate for cleanup only after verification

## jj workspaces

### /Users/emiller/src/personal/tnote

- Backend: jj
- Range checked: `trunk()..@`
- Status: The working copy has no changes.; Working copy (@) : rrkrtrrpn e31e0a973 (empty) (no description set); Parent commit (@-): oovtvoozv 94ef2e200 main | chore: add canonical check script
- Unlanded range: rrkrtrrp e31e0a97 9 hours ago ∅

### /Users/emiller/src/personal/macro-diff-refinement

- Backend: jj
- Range checked: `trunk()..@`
- Status: The working copy has no changes.; Working copy (@) : nxqoxnvwr a2b2c69cf (empty) (no description set); Parent commit (@-): qllwvzsqn 706dfcbb6 main | test: stabilize review flow after Effect migration
- Unlanded range: nxqoxnvw a2b2c69c 10 hours ago ∅

### /Users/emiller/src/personal/finances

- Backend: jj
- Range checked: `main@origin..main`
- Status: The working copy has no changes.; Working copy (@) : splnsxouq 737f65539 (empty) (no description set); Parent commit (@-): rsznlwppo 90fce66c4 main\* | fix(apple-card): import current purchases
- Unlanded range: rsznlwpp 90fce66c [20095261+edmundmiller] 25 minutes ago main\* fix(apple-card):; import current purchases; oklqtqzw 431e2531 [20095261+edmundmiller] 25 minutes ago test(apple-card):; cover CSV paths with spaces; vmntvynp 2442e86e [20095261+edmundmiller] 9 hours ago fix(lunchflow): require; ... (7 more; re-run live checkout inspection)
