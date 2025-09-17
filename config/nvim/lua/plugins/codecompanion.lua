return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    cmd = { "CodeCompanion", "CodeCompanionActions", "CodeCompanionChat" },
    config = function()
      require("codecompanion").setup({
        strategies = {
          chat = {
            adapter = "claude_code", -- Use Claude Code by default
          },
          inline = {
            adapter = "claude_code",
          },
          agent = {
            adapter = "claude_code",
          },
        },
        adapters = {
          -- Standard Anthropic API adapter (fallback)
          anthropic = function()
            return require("codecompanion.adapters").extend("anthropic", {
              env = {
                api_key = "ANTHROPIC_API_KEY",
              },
            })
          end,

          -- Claude Code via ACP (Anthropic Context Protocol)
          -- This gives you access to Claude Code's enhanced capabilities
          claude_code = function()
            return require("codecompanion.adapters").extend("claude_code", {
              env = {
                -- Option 1: Use OAuth token from Claude Pro subscription
                -- Run `claude setup-token` to get this token
                CLAUDE_CODE_OAUTH_TOKEN = vim.env.CLAUDE_CODE_OAUTH_TOKEN,

                -- Option 2: Use Anthropic API key (fallback)
                -- This will be used if OAuth token is not available
                ANTHROPIC_API_KEY = vim.env.ANTHROPIC_API_KEY,
              },
              -- Additional configuration for Claude Code features
              schema = {
                model = {
                  default = "claude-3-5-sonnet-20241022",
                },
              },
            })
          end,
        },

        -- Display configuration
        display = {
          chat = {
            window = {
              layout = "vertical", -- float|vertical|horizontal|buffer
              width = 0.45,
              height = 0.7,
            },
            show_settings = true,
            show_token_count = true,
          },
          diff = {
            provider = "mini_diff",
          },
        },

        -- Enable inline suggestions (like GitHub Copilot)
        inline = {
          adapter = "claude_code",
        },

        -- Log level for debugging
        log_level = "INFO",

        -- Send code and output as markdown
        send_code_as_markdown = true,
      })
    end,
    keys = {
      { "<leader>cc", "<cmd>CodeCompanionChat Toggle<cr>", desc = "Toggle CodeCompanion Chat" },
      { "<leader>ca", "<cmd>CodeCompanionActions<cr>", desc = "CodeCompanion Actions" },
      { "<leader>cp", "<cmd>CodeCompanionChat Add<cr>", mode = "v", desc = "Add to CodeCompanion Chat" },
      { "<leader>ci", "<cmd>CodeCompanion<cr>", desc = "Inline CodeCompanion" },
      { "<leader>cs", "<cmd>CodeCompanionChat Send<cr>", desc = "Send to CodeCompanion" },
      -- Additional keybindings for enhanced features
      { "<leader>ct", function()
          vim.cmd("CodeCompanionChat Toggle")
          vim.cmd("CodeCompanionChat Add")
        end, mode = "v", desc = "Toggle chat and add selection" },
    },
  },
}