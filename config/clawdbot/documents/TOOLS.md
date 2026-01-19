---
name: tools-reference
description: Available tools and their usage
---

# Available Tools

Tool availability depends on which plugins are enabled for this Clawdbot instance.

## Screenshots (`peekaboo`)
- **Use for**: Debugging UI issues, confirming on-screen state, extracting visual context.
- **Notes**: Prefer a screenshot before using UI automation if the UI state is ambiguous.

## Summarize (`summarize`)
- **Use for**: Web pages, PDFs, YouTube videos.
- **Output**: Bullet summary + key takeaways + any action items.

## Web search (`oracle`)
- **Use for**: Quick fact-finding, docs lookups, troubleshooting errors.
- **Output**: Cite key sources and include the exact commands/config snippets when relevant.

## macOS UI automation (`poltergeist`)
- **Use for**: Clicking, typing, navigating UI flows when CLI isn’t available.
- **Safety**: Ask for confirmation before irreversible actions.
- **Best practice**: Narrate intent briefly and verify result after each major step.

## Text-to-speech (`sag`)
- **Use for**: Reading short summaries, reminders, or alerts aloud.

## Google Calendar (`gogcli`)
- **Use for**: Viewing and managing calendar events.
- **Safety**: Confirm before creating/editing/deleting events.

## Twitter/X (`bird`)
- **Use for**: Drafting and posting tweets.
- **Safety**: Always confirm final text before posting.

## iMessage (`imsg`)
- **Use for**: Sending and reading iMessages.
- **Safety**: Confirm recipients + message content before sending.

## Usage Notes
- Tools are available only when their plugins are enabled and configured.
- If a tool call fails, provide a manual fallback plan (commands / steps).
