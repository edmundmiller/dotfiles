# Pi context repository

Git-backed `.pi/memory/` with `system/` pinned to the system prompt. Reminder
settings are saved: step-count is deterministic; compaction queues once and
drains next turn. Automatic reminders are system reminders, not user messages.

Reflection bundles belong in `.pi/reflection-runtime/`, outside memory Git
content. The `pi-context-repo:reflection-launch` event hands off work; if no
listener accepts it, preserve reminder fallback. This package prepares the
bundle/contract, not an autonomous background worker implementation.
