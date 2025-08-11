return {
  -- Configure Prettier for markdown formatting
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = vim.tbl_extend("force", opts.formatters_by_ft or {}, {
        markdown = { "prettier" },
        ["markdown.mdx"] = { "prettier" },
      })
      
      -- Configure prettier to respect project-specific configs
      opts.formatters = vim.tbl_extend("force", opts.formatters or {}, {
        prettier = {
          -- Prettier will automatically find and use .prettierrc.json in project root
          prepend_args = function(_, ctx)
            local prettier_config = vim.fn.findfile(".prettierrc.json", ctx.dirname .. ";")
            if prettier_config ~= "" then
              return { "--config", prettier_config }
            end
            -- Default args if no config found
            return {
              "--prose-wrap", "preserve",
              "--print-width", "100",
            }
          end,
        },
      })
      
      return opts
    end,
  },
  
  -- Ensure markdownlint works alongside prettier
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      -- Keep markdownlint but ensure it uses the right config
      opts.linters_by_ft.markdown = { "markdownlint" }
      
      -- Configure markdownlint to use project-specific config
      opts.linters = opts.linters or {}
      opts.linters.markdownlint = {
        args = function(ctx)
          local config_file = vim.fn.findfile(".markdownlint.json", ctx.dirname .. ";")
          if config_file ~= "" then
            return { "--config", config_file }
          end
          return {}
        end,
      }
      
      return opts
    end,
  },
}