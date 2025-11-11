-- Avante.nvim: AI assistant with Claude integration for AstroNvim
return {
  {
    "yetone/avante.nvim",
    enabled = false, -- Disabled in favor of claudecode.nvim
    build = vim.fn.has("win32") ~= 0
        and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
        or "make",
    event = "VeryLazy",
    version = false,
    opts = {
      -- Primary provider configuration
      provider = "claude",
      auto_suggestions_provider = "claude",

      -- Provider configurations
      providers = {
        claude = {
          endpoint = "https://api.anthropic.com",
          model = "claude-3-5-sonnet-20241022",
          timeout = 30000,
          extra_request_body = {
            temperature = 0.75,
            max_tokens = 8192,
          },
        },
      },

      -- Behavior settings
      behaviour = {
        auto_suggestions = false,
        auto_set_highlight_group = true,
        auto_set_keymaps = true,
        auto_apply_diff_after_generation = false,
        support_paste_from_clipboard = false,
        minimize_diff = true,
        enable_token_counting = true,
        auto_approve_tool_permissions = false,
      },

      -- Window configuration
      windows = {
        position = "right",
        wrap = true,
        width = 30,
        sidebar_header = {
          enabled = true,
          align = "center",
          rounded = true,
        },
        input = {
          prefix = "> ",
          height = 8,
        },
        edit = {
          border = "rounded",
          start_insert = true,
        },
        ask = {
          floating = false,
          start_insert = true,
          border = "rounded",
          focus_on_apply = "ours",
        },
      },

      -- Key mappings
      mappings = {
        diff = {
          ours = "co",
          theirs = "ct",
          all_theirs = "ca",
          both = "cb",
          cursor = "cc",
          next = "]x",
          prev = "[x",
        },
        suggestion = {
          accept = "<M-l>",
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
        jump = {
          next = "]]",
          prev = "[[",
        },
        submit = {
          normal = "<CR>",
          insert = "<C-s>",
        },
        cancel = {
          normal = { "<C-c>", "<Esc>", "q" },
          insert = { "<C-c>" },
        },
        sidebar = {
          apply_all = "A",
          apply_cursor = "a",
          retry_user_request = "r",
          edit_user_request = "e",
          switch_windows = "<Tab>",
          reverse_switch_windows = "<S-Tab>",
          remove_file = "d",
          add_file = "@",
          close = { "<Esc>", "q" },
        },
      },

      -- Diff configuration
      diff = {
        autojump = true,
        list_opener = "copen",
        override_timeoutlen = 500,
      },

      -- Suggestion timing
      suggestion = {
        debounce = 600,
        throttle = 600,
      },

      -- Custom shortcuts for common tasks
      shortcuts = {
        {
          name = "refactor",
          description = "Refactor code with best practices",
          details = "Automatically refactor code to improve readability, maintainability, and follow best practices",
          prompt = "Please refactor this code following best practices, improving readability and maintainability while preserving functionality.",
        },
        {
          name = "test",
          description = "Generate unit tests",
          details = "Create comprehensive unit tests covering edge cases and error scenarios",
          prompt = "Please generate comprehensive unit tests for this code, covering edge cases and error scenarios.",
        },
        {
          name = "explain",
          description = "Explain code in detail",
          details = "Provide a detailed explanation of what this code does and how it works",
          prompt = "Please explain this code in detail, including its purpose, how it works, and any important implementation details.",
        },
        {
          name = "optimize",
          description = "Optimize for performance",
          details = "Optimize this code for better performance while maintaining correctness",
          prompt = "Please optimize this code for better performance, focusing on time and space complexity improvements while maintaining correctness.",
        },
      },

      -- Project-specific instructions
      instructions_file = "avante.md",
    },

    -- Dependencies
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-telescope/telescope.nvim",
      -- Blink.compat for blink.cmp integration
      {
        "saghen/blink.compat",
        opts = {},
      },
      -- Image support
      {
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            use_absolute_path = true,
          },
        },
      },
      -- Markdown rendering
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = function(_, opts)
          opts.file_types = vim.list_extend(opts.file_types or { "markdown" }, { "Avante" })
          return opts
        end,
      },
    },

    -- Key bindings following Doom conventions
    keys = {
      -- Main Avante commands under <leader>a
      { "<leader>aa", "<cmd>AvanteAsk<cr>", desc = "Ask Avante" },
      { "<leader>ac", "<cmd>AvanteChat<cr>", desc = "Open Avante Chat" },
      { "<leader>ae", "<cmd>AvanteEdit<cr>", desc = "Edit with Avante" },
      { "<leader>ar", "<cmd>AvanteRefresh<cr>", desc = "Refresh Avante" },
      { "<leader>at", "<cmd>AvanteToggle<cr>", desc = "Toggle Avante" },
      { "<leader>af", "<cmd>AvanteFocus<cr>", desc = "Focus Avante" },
      { "<leader>as", "<cmd>AvanteShowRepo<cr>", desc = "Show Repository Context" },
      { "<leader>ab", "<cmd>AvanteBuild<cr>", desc = "Build Project Context" },
      { "<leader>ax", "<cmd>AvanteClear<cr>", desc = "Clear Avante" },

      -- Visual mode bindings
      { "<leader>aa", "<cmd>AvanteAsk<cr>", mode = "v", desc = "Ask Avante about selection" },
      { "<leader>ae", "<cmd>AvanteEdit<cr>", mode = "v", desc = "Edit selection with Avante" },
    },
  },

  -- Blink.cmp configuration for Avante sources
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      -- Add Avante sources to the default sources
      opts.sources = opts.sources or {}
      opts.sources.default = vim.list_extend(
        opts.sources.default or {},
        { "avante_commands", "avante_mentions", "avante_shortcuts", "avante_files" }
      )

      -- Configure Avante-specific providers
      opts.sources.providers = vim.tbl_deep_extend("force", opts.sources.providers or {}, {
        avante_commands = {
          name = "avante_commands",
          module = "blink.compat.source",
          score_offset = 90,
          opts = {},
        },
        avante_files = {
          name = "avante_files",
          module = "blink.compat.source",
          score_offset = 100,
          opts = {},
        },
        avante_mentions = {
          name = "avante_mentions",
          module = "blink.compat.source",
          score_offset = 1000,
          opts = {},
        },
        avante_shortcuts = {
          name = "avante_shortcuts",
          module = "blink.compat.source",
          score_offset = 1000,
          opts = {},
        },
      })

      return opts
    end,
  },
}