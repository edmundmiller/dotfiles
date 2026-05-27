#!/usr/bin/env bash
# activity-scrape.sh — scrape Slack's "Activity" inbox to a TSV via agent-browser.
#
# The Activity view (app.slack.com/client/<TEAM>/activity-inbox) is Slack's
# curated feed of things addressed to you: @mentions, @channel/@here/group
# broadcasts, thread replies, reactions, invitations. It is FAR higher signal
# than scrolling all unread channels, and — unlike opening a channel — viewing
# it does NOT mark channel messages read.
#
# This is READ-ONLY: it scrolls and reads the DOM, never clicks "Mark as Read",
# never opens a channel, never sends. Channel unread badges stay intact.
#
# It produces deterministic structured data; the SYNTHESIS (the human-readable
# digest) is the agent's job — read the TSV and summarize. Dispatch this whole
# thing to a sub-agent so the raw items never touch the main context window.
#
# Usage:   activity-scrape.sh [OUTFILE]
#   OUTFILE defaults to /tmp/slack_activity.txt
#   SLACK_DEBUG_PORT env overrides the CDP port (default 9222).
#
# Output TSV columns:  type <TAB> channel <TAB> sender <TAB> timestamp <TAB> body
#   type ∈ mention | channel-mention | group-mention | thread | reaction | invite | other
#
# Prereq: Helium (or any Chromium) running with --remote-debugging-port=9222 and
# logged into the target Slack workspace, with Slack open in some tab. See SKILL.md.

set -uo pipefail

PORT="${SLACK_DEBUG_PORT:-9222}"
OUT="${1:-/tmp/slack_activity.txt}"

agent-browser connect "$PORT" >/dev/null 2>&1 || { echo "connect $PORT failed — is Helium up with --remote-debugging-port=$PORT?" >&2; exit 1; }

# Find a Slack tab and its workspace/team id from the tab list.
line=$(agent-browser tab 2>&1 | grep -iE 'app\.slack\.com/client' | head -1)
[ -z "$line" ] && { echo "No Slack tab open. Open Slack in the browser first." >&2; exit 1; }
TEAM=$(printf '%s' "$line" | grep -oE 'client/[A-Z0-9]+' | head -1 | cut -d/ -f2)
TAB=$(printf '%s' "$line"  | grep -oE '\[t[0-9]+\]'      | head -1 | tr -d '[]')
[ -z "$TEAM" ] && { echo "Could not parse workspace id from: $line" >&2; exit 1; }

T(){ agent-browser tab "$TAB" >/dev/null 2>&1; }   # re-assert tab — the active tab DRIFTS

# Navigate to the Activity inbox (idempotent). Tab label may renumber after nav.
T; agent-browser tab "https://app.slack.com/client/$TEAM/activity-inbox" >/dev/null 2>&1
sleep 3
TAB=$(agent-browser tab 2>&1 | grep -iE 'activity-inbox' | grep -oE '\[t[0-9]+\]' | head -1 | tr -d '[]')
[ -z "$TAB" ] && { echo "Could not open activity-inbox tab" >&2; exit 1; }

# Per-item extractor. Body = longest .c-truncate text that isn't the channel name
# (channel names are short, message previews long). Type inferred from label text.
# Returns a JS ARRAY (not a string): agent-browser then emits valid JSON, which we
# parse with `jq -r '.[] | @tsv'`. (Returning a joined string instead gets the \n/\t
# JSON-escaped into literal backslash sequences — the array path avoids that.)
EX='(()=>{const sc=[...document.querySelectorAll(".c-scrollbar__hider")].find(e=>e.querySelector("[role=listitem]")); if(!sc)return []; const items=[...sc.querySelectorAll("[role=listitem]")]; const out=[]; for(const it of items){const sender=((it.querySelector("[class*=\"sender_name\"]")||{}).textContent||"").trim(); const ch=((it.querySelector(".c-channel_entity__name")||{}).textContent||"").trim(); const full=it.textContent||""; let type="other"; if(/Group mention/.test(full))type="group-mention"; else if(/Channel mention/.test(full))type="channel-mention"; else if(/Mention in/.test(full))type="mention"; else if(/Thread in|replied|repl/.test(full))type="thread"; else if(/invited you/.test(full))type="invite"; else if(/reacted/.test(full))type="reaction"; let body=""; for(const t of it.querySelectorAll(".c-truncate,[class*=\"rich_text\"]")){const x=(t.textContent||"").trim(); if(x&&x!==ch&&x.length>body.length)body=x;} body=body.replace(/\s+/g," ").trim(); if(ch&&body.startsWith(ch))body=body.slice(ch.length).trim(); if(ch||body)out.push([type,ch,sender,ts=((it.querySelector("[class*=\"timestamp_variant_wide\"]")||{}).textContent||"").trim(),body.slice(0,450)]);} return out;})()'
SCROLL='(()=>{const sc=[...document.querySelectorAll(".c-scrollbar__hider")].find(e=>e.querySelector("[role=listitem]")); if(!sc)return "END"; sc.scrollTop=Math.min(sc.scrollTop+Math.floor(sc.clientHeight*0.8), sc.scrollHeight); return (sc.scrollTop>=sc.scrollHeight-sc.clientHeight-5)?"END":"MORE";})()'

# Reset to top, then scroll-and-extract to the bottom (the feed is virtualized:
# only ~24 rows render at a time, so we must scroll and accumulate).
T; agent-browser eval "(()=>{const sc=[...document.querySelectorAll('.c-scrollbar__hider')].find(e=>e.querySelector('[role=listitem]')); if(sc)sc.scrollTop=0; return 'OK';})()" >/dev/null 2>&1
sleep 1
: > "$OUT"
for i in $(seq 1 30); do
  T; agent-browser eval "$EX" 2>&1 | jq -r '.[] | @tsv' >> "$OUT" 2>/dev/null
  T; more=$(agent-browser eval "$SCROLL" 2>&1 | tr -d '"'); sleep 0.9
  [ "$more" = "END" ] && break
done
awk '!seen[$0]++' "$OUT" > "$OUT.tmp" && command mv -f "$OUT.tmp" "$OUT"

echo "Wrote $(wc -l < "$OUT" | tr -d ' ') items to $OUT (team=$TEAM)"
echo "By type:"; cut -f1 "$OUT" | sort | uniq -c | sort -rn
