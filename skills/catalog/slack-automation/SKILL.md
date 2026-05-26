---
name: slack-automation
description: >
  Automate Slack sidebar housekeeping (mute, leave, move-to-section, reach hidden
  channels, inventory) via agent-browser browser automation. Use when the user
  wants to "clean up my Slack", mute noisy channels, leave channels, reorganize
  sidebar sections, or bulk-triage channels. Builds on the base agent-browser
  `slack` skill — load that first for connect/snapshot/click basics.
license: MIT
---

# Slack Automation (sidebar housekeeping)

Layer on top of the base Slack skill for actions it doesn't cover: muting,
leaving, moving channels between sections, reaching hidden channels, and taking a
full inventory. Get the basics (connect, snapshot, click, search) first:

```bash
agent-browser skills get slack
```

## Connecting (Helium, this user's setup)

The daily browser is **Helium** (`/Applications/Helium.app`), Chromium-based, and
runs WITHOUT a debug port by default. To attach, the user must relaunch it (run
via the `!` prefix so output lands in-session):

```bash
osascript -e 'quit app "Helium"'; sleep 2; open -a Helium --args --remote-debugging-port=9222
agent-browser connect 9222
```

Uses the real profile, so logged-in sessions persist. **Gotcha:** the profile is
signed into the _Seqera_ workspace but NOT _nf-core_ — nf-core needs a separate
Google/email login with a reCAPTCHA. Don't attempt the CAPTCHA; hand login to the
user. Open the workspace in a new tab: `agent-browser tab "https://app.slack.com/client"`.

## The two rules that cause most failures

1. **The active tab drifts.** agent-browser acts on whatever tab is active, and it
   changes when anything touches the browser. Re-assert the Slack tab before every
   command: `agent-browser tab <tNN>` (find it with `agent-browser tab | grep -i slack`).
2. **Snapshot refs (`@eNN`) are single-generation.** The next `snapshot`/`eval`
   invalidates them, and `agent-browser click @ref` then **fails silently** (reports
   success, does nothing). Don't drive menus by ref.

## Core technique: context menus via `eval`, clicked by text

agent-browser has no native right-click. Open Slack's channel menu by dispatching a
synthetic `contextmenu` event with `eval`, then click items **by text** (also via
`eval`). Do NOT `snapshot` between opening and clicking — a snapshot closes the menu.
Menu opening is racy; retry-fire until the target item is present.

All of this is packaged in `scripts/slack-lib.sh`:

```bash
export SLACK_TAB=$(source scripts/slack-lib.sh 2>/dev/null; sl_find_tab)  # or set manually, e.g. t44
source scripts/slack-lib.sh

sl_mute genephylo                 # "Mute and hide" (see below)
sl_leave taxprofiler              # leave a visible channel
sl_open_and_leave detectseq       # leave a hidden/muted channel
sl_move_to_section configs_core_private Infrastructure
sl_inventory                      # {section: [channels]} JSON
```

Pass the **bare** channel name; the helpers strip Slack's trailing unread badge
(`genephylo1`, `request-review9+`).

## Tidbits learned the hard way

- **Mute == "Mute and hide".** Current Slack has no plain mute — the only option is
  the `Mute and hide` radio, which removes the channel from the sidebar entirely
  (reappears only on direct @mention). So muting and "moving to a section" conflict:
  a muted channel won't show in its section. Decide which you want.
- **Hidden channels aren't in the DOM.** You can't right-click a muted/hidden channel
  in the sidebar. Open it via the quick switcher (`Meta+k` → type → `Enter`); it then
  appears as the **active** row and behaves like any visible channel. `sl_open` does this.
- **Leaving is reliable and reversible-ish.** `Leave channel` is a top-level menu item
  (no submenu); public channels leave with no confirmation dialog. Rejoining a public
  channel is one click. Leaving still lets **user-group** mentions (`@core`,
  `@maintainers`) reach the user — group pings notify members regardless of channel
  membership. What's lost: `@channel`/`@here` in that channel, and being @-able there.
- **Submenu flyouts need a REAL hover.** "Move channel" → section opens only on a
  genuine pointer hover. Synthetic `mouseover`/keyboard won't open it. Tag the parent
  with an `id` via eval, then `agent-browser hover #id` (native CDP pointer). `sl_move_to_section` does this.
- **The Filter submenu resists automation.** Per-section Filter (Active only / Unreads /
  Mentions / All) would NOT open via synthetic hover OR keyboard. Leave that toggle to
  the user — it's a 2-click manual change (right-click section header → Filter).
- **The sidebar is a virtualized list.** A single snapshot/eval only sees rendered rows
  (unread ones float to the top). Scroll the `.c-virtual_list__scroll_container` and
  merge reads to get the full picture before proposing bulk changes.
- **Confirm destructive bulk actions explicitly.** Leaving many channels is a
  hard-to-retract external write; the auto-approval classifier will (correctly) block a
  batch built from tentative ("maybe") instructions. Nail down the exact list first.

## Workflow for a "clean up my Slack" request

1. Connect, confirm the right workspace tab, `sl_inventory` (scroll for completeness).
2. Propose a concrete plan grouped by action (mute / leave / move) and confirm — these
   changes are user-specific judgment calls, not defaults.
3. Apply with the helpers, verifying each channel (`STILL PRESENT`/`STILL VISIBLE` = retry).
4. Report what changed and any manual-only leftovers (e.g. the Filter toggle).
