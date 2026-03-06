---
name: heartbeat
description: Native heartbeat checklist — runs every 30m with full session context
---

# Heartbeat Checklist

## Quick Checks

1. **Inbox scan** — anything urgent in agentmail?
   ```bash
   curl -sf -H "Authorization: Bearer $AGENTMAIL_API_KEY" https://api.agentmail.to/v0/inboxes | jq -r '.inboxes[]? | "\(.address): \(.unread_count // 0) unread"' 2>/dev/null || echo 'email=unavailable'
   ```
2. **New Linear issues** — check for issues created in the last 2h:
   ```bash
   SINCE=$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2H +%Y-%m-%dT%H:%M:%SZ)
   curl -sf -X POST https://api.linear.app/graphql \
     -H "Authorization: $LINEAR_API_KEY" \
     -H "Content-Type: application/json" \
     -d "{\"query\":\"{ issues(filter: { createdAt: { gte: \\\"$SINCE\\\" }, state: { type: { nin: [\\\"canceled\\\", \\\"completed\\\"] } } }, orderBy: createdAt, first: 10) { nodes { identifier title state { name } priority createdAt } } }\"}" \
     | jq -r '.data.issues.nodes[]? | "\(.identifier) [\(.state.name)] P\(.priority) \(.title)"' 2>/dev/null || echo 'linear=unavailable'
   ```
   If new issues exist, mention them briefly. High priority (P1/P2) issues are urgent.
3. **Blocked tasks** — if any task is waiting on input, note what's missing

## Rules

- If nothing needs attention: reply `HEARTBEAT_OK`
- If something is urgent: describe it concisely (no HEARTBEAT_OK)
- Keep responses under 3 lines
- Don't repeat old tasks from prior chats
