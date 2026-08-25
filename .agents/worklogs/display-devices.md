# Worklog: display-devices

Status: blocked

## Objective

Make the BUSY Bar, TRMNL OG, and TRMNL X declaratively hackable by agents from dotfiles. Stop when agents have bounded preview/apply/readback commands, the BUSY bedtime graphic is improved and exercised on hardware through Home Assistant, TRMNL templates render for both device sizes, focused checks pass, and the changes are published with remote equality.

## Decisions

- Dotfiles owns local device inventory, host tooling, secrets, and the existing Home Assistant schedule. Tailnet remains limited to cloud/network resources; Obsidian and mill-docs remain content/context sources.
- Preserve BUSY Bar application namespaces, priority, scoped clear, and timeouts so an agent cannot erase unrelated apps or preempt an active BUSY session accidentally.
- Use TRMNL's official TRMNLP project format and Account API instead of inventing a renderer or self-hosted server.
- Keep the command client standard-library-only and noninteractive. Local preview/readback must work without secrets; every remote mutation requires an explicit apply flag and emits structured JSON without secret values.
- Add one global `display-devices` skill that routes agents to the CLI. Device addresses, identifiers, and secret references remain in generated config rather than skill prose.
- Simplify the 72x16 bedtime face to a native countdown above a framed five-segment progress bar; remove unreadable minute labels while preserving the six-minute state model.

## Evidence

- Current BUSY Bar answered over USB and LAN with firmware 1.1.1 and API 25.0.0; Wi-Fi is connected at the existing declarative address.
- Official BUSY Bar firmware OpenAPI and TRMNL API/OpenAPI/TRMNLP documentation were inspected on 2026-08-24.
- TRMNL's live model registry identifies the OG canvas as 800x480 and TRMNL X as 1872x1404 with 16 grayscale levels. TRMNL devices pull server-rendered images; account/plugin state and current-screen telemetry are therefore required for live proof.
- The checked-in TRMNLP project renders all four layouts at OG and X logical sizes. The full previews are 800x480 1-bit and 1040x780 4-bit, with separate foreground assertions for the headline and message regions.
- BUSY front-screen application was exercised over both USB and LAN with `filled_count = 2`: two cyan segments, one amber segment, two dim segments, framed track, and white countdown were verified by exact framebuffer pixels. Both scoped clear operations returned all 1,152 pixels to black.
- The deployed Home Assistant `rest_command.busy_bar_bedtime_draw` and `rest_command.busy_bar_bedtime_clear` were exercised over LAN. The physical frame matched the same pixel contract, and `light.busy_bar` remained unchanged. The hidden automation event branch was not fired because `input_boolean.goodnight_done` and `input_boolean.sleep_done` were already `on`; those household states were left untouched.
- NUC generation `/nix/store/k982ql80f84fcvm29byy2xxzpq4gbxmf-nixos-system-nuc-26.11.20260714.18b9261` is active. All six Hermes gateways are active, all six containers resolve the final `displayctl` package/config, and the one-hour overlay limit rejects unsafe input. The live doctor reaches the BUSY LAN target with HTTP 200; USB is correctly unreachable from the NUC, and TRMNL capability rows report the intentionally absent enrollment credentials without exposing values.
- Mac activation initially failed with `No space left on device`. A bounded `nix store gc --max 20G` removed only unreachable, rebuildable Nix store paths and increased free space from 2.5 GB to 27 GB; the activation retry is tracked below.

## Reviews

- Release review found five blockers: the TRMNL webhook envelope, BUSY element IDs, priority/timeout enforcement, explicit Hermes profile wiring, and weak TRMNL render assertions. Each was fixed and covered by focused tests before deployment.
- A final independent read-only release review found no remaining release blockers after the fixes.

## Feedback

- `PYTHONDONTWRITEBYTECODE=1 python3 packages/displayctl/test_displayctl.py` is the red baseline: 7 contract tests fail because `packages/displayctl/displayctl` does not exist yet. The test harness itself starts mock HTTP servers and confirms the intended failure is at the missing executable boundary.
- The displayctl contract is green at 9 tests; `ruff check` passes, `nixfmt --check modules/shell/displayctl.nix` passes, and the package builds from a path flake on aarch64-darwin. Both Darwin and NixOS module evaluations resolve the declarative `~/.config/displayctl/config.json` text.
- The TRMNL payload extension starts red as expected: the new full-payload and dry-run tests fail at argparse because the optional template flags are not implemented yet; the invalid-progress test already confirms no request is sent on malformed input.
- BUSY frame-order regression is red only for the back display: the known `0xE1` L4 fixture renders high-nibble-first under the current decoder, proving the low-nibble-first fix is still required.
- The TRMNL payload and BUSY frame fixes are green: 14 contract tests pass, including full agent-message fields, progress rejection, BGR-to-RGB pixels, and low-nibble-first L4 grayscale pixels. `ruff`, `nixfmt`, package build, both host evaluations, and live USB PNG capture pass again.
- BUSY safety-boundary tests are red as expected: 20 tests run with failures for unsafe application names, priority 51, missing/zero element timeouts, and missing message timeout support. The existing 14 tests remain otherwise green.
- BUSY safety-boundary hardening is green: 20 contract tests pass with OpenAPI-safe application names, a priority ceiling of 50, mandatory positive element timeouts, and bounded `busy message --timeout` behavior. `ruff`, `nixfmt`, and the package build pass.
- Live BUSY/TRMNL boundary tests are red as expected: 27 tests expose missing element IDs/fonts/countdown/rectangle/source validation, missing HTTP error detail, and the TRMNL webhook envelope still being direct fields instead of `merge_variables`.
- Live BUSY/TRMNL boundary hardening is green: 28 contract tests pass with OpenAPI element validation, bounded/redacted HTTP error detail, and the private-plugin `merge_variables` webhook envelope. Default config discovery now prefers `DISPLAYCTL_CONFIG`, then user, installed, and source configs; the package installs its config at `share/displayctl/config.json`.
- Safe auth metadata is readable while credential values remain redacted: 29 contract tests pass, including `token_required: false` for the current BUSY LAN no-key mode.
- The final suite has 32 displayctl contract tests. `./bin/hey check --worktree /Users/emiller/.config/dotfiles.display-devices`, the Home Assistant automation assertion derivation, the displayctl package build, TRMNLP structural/render/lint checks for both OG and X, the registered offline Linux render, skill validation, and the exact NUC build/dry-activate/switch all pass.

## Remaining work

- `dotfiles-enroll-trmnl-agent-message-mmjy`: authenticate the attached TRMNL browser session, verify the account and both device IDs, create or link exactly one Agent Message private plugin, replace the guarded `__UNASSIGNED__` settings ID, provision secret-backed webhook/device/API variables, and prove server plus physical-device readback.
- `dotfiles-repair-darwin-h5py-activation-k05f`: repair the existing h5py 3.15.1 test abort and complete the Mac generation switch. The displayctl package and current Darwin configuration already build/evaluate independently.

## Commits

- `98964f1a1 feat(display): add agent-safe device control`
- `c9863d502 feat(trmnl): add agent message authoring project`
- `a6b470bae feat(hass): simplify BUSY bedtime progress`
- `363d0b10d fix(display): expose safe auth metadata`
- `7e67494f5 fix(display): harden publishing and verification`

After landing, create annotated tag `agent-work/display-devices`.
