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
2. **Blocked tasks** — if any task is waiting on input, note what's missing
3. **Daytime check-in** — if nothing pending and it's daytime, a brief "anything you need?" is fine

## Rules

- If nothing needs attention: reply `HEARTBEAT_OK`
- If something is urgent: describe it concisely (no HEARTBEAT_OK)
- Keep responses under 3 lines
- Don't repeat old tasks from prior chats
