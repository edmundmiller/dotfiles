#!/usr/bin/env bash
# slack-lib.sh — reusable helpers for driving Slack's sidebar via agent-browser.
#
# These cover the things the base `agent-browser skills get slack` skill does NOT:
# sidebar context menus, mute, leave, move-to-section, and reaching hidden channels.
# The trick throughout: open Slack's native right-click menu by dispatching a
# synthetic `contextmenu` event via `agent-browser eval`, then click menu items
# BY TEXT via eval. This sidesteps snapshot-ref churn, which silently breaks
# `agent-browser click @ref`.
#
# Usage:  export SLACK_TAB=t44 ; source slack-lib.sh ; sl_mute genephylo
# Find the tab label with: agent-browser tab | grep -i slack
#
# Channel-name matching strips Slack's trailing unread badge ("genephylo1",
# "request-review9+") so you pass the bare name ("genephylo", "request-review").

: "${SLACK_TAB:?set SLACK_TAB to the Slack tab label, e.g. export SLACK_TAB=t44}"

# Re-assert the Slack tab before every command — the active tab DRIFTS when the
# user (or another process) touches the browser, and agent-browser acts on
# whatever tab is active.
sl_tab() { agent-browser tab "$SLACK_TAB" >/dev/null 2>&1; }

# Print the Slack tab label so callers can `export SLACK_TAB=$(sl_find_tab)`.
sl_find_tab() { agent-browser tab 2>&1 | grep -i 'slack' | grep -oE '\[t[0-9]+\]' | head -1 | tr -d '[]'; }

# JS snippet (string) that locates a sidebar channel row by bare name.
_sl_find_js() {
  cat <<JS
const name=$(printf '%s' "$1" | sed 's/"/\\"/g; s/^/"/; s/$/"/');
const el=[...document.querySelectorAll(".p-channel_sidebar__channel")].find(e=>{
  const t=(e.textContent||"").trim();
  return t===name || (t.startsWith(name) && /^[0-9+]*\$/.test(t.slice(name.length)));
});
JS
}

# Fire a right-click context menu on a sidebar channel. Echoes FIRED / NOTFOUND.
sl_fire_ctx() {
  sl_tab
  agent-browser eval "(() => {
    $(_sl_find_js "$1")
    if(!el) return 'NOTFOUND';
    const r=el.getBoundingClientRect(),x=r.left+r.width/2,y=r.top+r.height/2;
    for(const ty of ['pointerdown','mousedown','pointerup','mouseup','contextmenu'])
      el.dispatchEvent(new MouseEvent(ty,{bubbles:true,cancelable:true,view:window,button:2,buttons:2,clientX:x,clientY:y}));
    return 'FIRED';
  })()" 2>&1 | tr -d '"'
}

# Click an open menu item whose text matches a JS regex (default: anchored).
# IMPORTANT: do NOT take a snapshot between fire and click — snapshot closes the menu.
sl_click_menu() {
  sl_tab
  agent-browser eval "(() => {
    const item=[...document.querySelectorAll('[role=menuitem],[role=menuitemradio]')]
      .find(e=>/$1/i.test((e.textContent||'').trim()));
    if(!item) return 'NOITEM';
    const r=item.getBoundingClientRect(),x=r.left+r.width/2,y=r.top+r.height/2;
    for(const ty of ['pointermove','pointerover','pointerdown','mousedown','pointerup','mouseup','click'])
      item.dispatchEvent(new MouseEvent(ty,{bubbles:true,cancelable:true,view:window,button:0,buttons:1,clientX:x,clientY:y}));
    return 'CLICKED';
  })()" 2>&1 | tr -d '"'
}

# True if a channel is currently visible in the sidebar.
sl_visible() {
  sl_tab
  local r
  r=$(agent-browser eval "(() => { $(_sl_find_js "$1") return el?'1':'0'; })()" 2>&1 | tr -d '"')
  [[ "$r" == 1 ]]
}

# Mute & hide a channel. In current Slack the only mute option is the
# "Mute and hide" radio (removes it from the sidebar; reappears only on @mention).
sl_mute() {
  [[ "$(sl_fire_ctx "$1")" == FIRED ]] || { echo "[$1] not found"; return 1; }
  sleep 0.9
  sl_click_menu 'Mute and hide' >/dev/null
  sleep 0.8; agent-browser press Escape >/dev/null 2>&1
  sl_visible "$1" && echo "[$1] STILL VISIBLE (retry)" || echo "[$1] muted+hidden"
}

# Leave a channel that is currently in the sidebar.
# "Leave channel" is a top-level menu item; public channels leave with no dialog.
sl_leave() {
  [[ "$(sl_fire_ctx "$1")" == FIRED ]] || { echo "[$1] not found"; return 1; }
  sleep 0.8
  sl_click_menu '^Leave channel' >/dev/null
  sleep 1; agent-browser press Escape >/dev/null 2>&1
  sl_visible "$1" && echo "[$1] STILL PRESENT" || echo "[$1] left"
}

# Open a channel by name via the quick switcher (Cmd/Meta+K). Needed to reach
# muted+hidden channels, which are absent from the sidebar — opening one makes it
# appear as the ACTIVE row, after which sl_leave/sl_mute work on it normally.
sl_open() {
  agent-browser press Escape >/dev/null 2>&1; sleep 0.3
  sl_tab; agent-browser press Meta+k >/dev/null 2>&1; sleep 0.7
  sl_tab; agent-browser keyboard type "$1" >/dev/null 2>&1; sleep 1.1
  sl_tab; agent-browser press Enter >/dev/null 2>&1; sleep 1.3
}

# Leave a channel whether or not it's hidden: open it first, then leave.
sl_open_and_leave() { sl_open "$1"; sl_leave "$1"; }

# Move a channel into a named section via the "Move channel" submenu.
# Submenu flyouts need a REAL pointer hover (synthetic mouseover won't open them):
# tag the parent item with an id, then use native `agent-browser hover #id`.
# Menu open is racy; retry-fire until the parent item is found.
sl_move_to_section() {
  local ch="$1" section="$2" i
  for i in 1 2 3 4 5; do
    sl_fire_ctx "$ch" >/dev/null; sleep 0.9
    sl_tab
    local r
    r=$(agent-browser eval "(() => {
      const it=[...document.querySelectorAll('[role=menuitem]')].find(e=>/^Move channel/i.test((e.textContent||'').trim()));
      if(!it) return 'NOITEM'; it.id='abMoveTarget'; return 'TAGGED';
    })()" 2>&1 | tr -d '"')
    [[ "$r" == TAGGED ]] && break
    agent-browser press Escape >/dev/null 2>&1; sleep 0.4
  done
  sl_tab; agent-browser hover '#abMoveTarget' >/dev/null 2>&1; sleep 1.6
  sl_tab
  agent-browser eval "(() => {
    const tgt=[...document.querySelectorAll('[role=menuitem],[role=menuitemradio],[role=option]')]
      .find(e=>{const t=(e.textContent||'').trim(); return /$section/i.test(t) && !/Move channel/i.test(t);});
    if(!tgt) return 'NOSECTION';
    const r=tgt.getBoundingClientRect(),x=r.left+r.width/2,y=r.top+r.height/2;
    for(const ty of ['pointermove','pointerover','pointerdown','mousedown','pointerup','mouseup','click'])
      tgt.dispatchEvent(new MouseEvent(ty,{bubbles:true,cancelable:true,view:window,button:0,buttons:1,clientX:x,clientY:y}));
    return 'MOVED:'+(tgt.textContent||'').trim();
  })()" 2>&1 | tr -d '"'
}

# Dump the full sidebar as {section: [channels]} JSON. Scroll first — the list is
# VIRTUALIZED, so a single read only sees rows currently rendered in the viewport.
sl_inventory() {
  sl_tab
  agent-browser eval "(() => {
    let sec='?'; const seen={};
    document.querySelectorAll('.p-channel_sidebar__section_heading, .p-channel_sidebar__channel').forEach(e=>{
      if(e.classList.contains('p-channel_sidebar__section_heading')) sec=(e.textContent||'').trim();
      else { const t=(e.textContent||'').trim(); if(t)(seen[sec]=seen[sec]||new Set()).add(t); }
    });
    return JSON.stringify(Object.fromEntries(Object.entries(seen).map(([k,v])=>[k,[...v]])));
  })()" 2>&1
}
