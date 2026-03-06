---
name: heartbeat
description: External heartbeat check — invoked by systemd timer every 30 minutes
---

# Heartbeat Check

You're being called by an external systemd timer to verify you're alive and functional.

## What to Do

Run a quick self-diagnostic:

1. **Confirm you can reason** — you're reading this, so yes
2. **Check tool access** — try listing your workspace: `ls ~/`
3. **Check email** — list agentmail inboxes to verify API connectivity:
   ```bash
   curl -sf -H "Authorization: Bearer $AGENTMAIL_API_KEY" https://api.agentmail.to/v0/inboxes | head -c 200
   ```
   If curl fails or returns an error, report `email=error`.
4. **Report status** — respond with a one-line summary

## Response Format

Reply with exactly one line:

```
OK: [timestamp] tools=working memory=[ok/error] email=[ok/error] uptime=[if known]
```

If something is broken, say what:

```
DEGRADED: [timestamp] tools=working memory=error email=ok reason="lancedb connection refused"
```

Keep it short. This output gets attached to the healthchecks.io ping.
