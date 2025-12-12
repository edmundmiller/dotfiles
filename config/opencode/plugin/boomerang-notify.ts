// Boomerang notification plugin
// Sends desktop notifications when child sessions complete
import type { Plugin } from "@opencode-ai/plugin"

export const BoomerangNotify: Plugin = async ({ $ }) => {
  // Track parent sessions to know which completions to notify about
  const parentSessions = new Set<string>()

  return {
    event: async ({ event }) => {
      // Track when sessions are created with parents (child sessions)
      if (event.type === "session.created") {
        const session = event.properties as any
        if (session?.parentID) {
          parentSessions.add(session.parentID)
        }
      }

      // Notify when a child session completes
      if (event.type === "session.idle") {
        const session = event.properties as any

        // Check if this session has a parent (is a child session)
        if (session?.parentID && parentSessions.has(session.parentID)) {
          const title = session.title || "Child task"

          // macOS notification
          try {
            await $`osascript -e 'display notification "Subtask completed: ${title}" with title "Boomerang"'`
          } catch {
            // Notification failed, not critical
          }
        }
      }

      // Clean up when parent session ends
      if (event.type === "session.deleted") {
        const session = event.properties as any
        if (session?.id) {
          parentSessions.delete(session.id)
        }
      }
    },
  }
}
