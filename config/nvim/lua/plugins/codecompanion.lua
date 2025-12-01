-- CodeCompanion customization - layers on top of AstroCommunity import
-- AstroCommunity provides: keymaps, heirline spinner, icons, markdown rendering
-- This adds: claude_code adapter with OAuth token authentication
return {
  "olimorris/codecompanion.nvim",
  opts = {
    adapters = {
      acp = {
        claude_code = function()
          return require("codecompanion.adapters").extend("claude_code", {
            env = {
              -- Reads from CLAUDE_CODE_OAUTH_TOKEN environment variable
              CLAUDE_CODE_OAUTH_TOKEN = "CLAUDE_CODE_OAUTH_TOKEN",
            },
          })
        end,
      },
    },
    strategies = {
      chat = {
        adapter = "claude_code",
      },
      inline = {
        adapter = "claude_code",
      },
    },
  },
}
