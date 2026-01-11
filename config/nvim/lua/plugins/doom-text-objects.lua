-- Doom Emacs-style custom text objects
-- Provides additional text objects beyond Vim's built-in ones

return {
  -- Extend mini.ai with custom text objects
  -- LazyVim already includes mini.ai, so we're just extending its configuration
  {
    "nvim-mini/mini.ai",
    event = "VeryLazy",
    opts = function(_, opts)
      local ai = require("mini.ai")
      
      -- Merge our custom text objects with existing ones
      opts.custom_textobjects = vim.tbl_extend("force", opts.custom_textobjects or {}, {
        -- Entire buffer (g)
        g = function()
          local from = { line = 1, col = 1 }
          local to = {
            line = vim.fn.line("$"),
            col = math.max(vim.fn.getline("$"):len(), 1),
          }
          return { from = from, to = to }
        end,
        -- URLs (u)
        u = { "https?://[%w-_%.%?%.:/%+=&]+", "^().*()$" },
      })
      
      -- mini.ai already provides:
      -- a = argument
      -- b = brackets )]}
      -- f = function call
      -- q = quote
      -- t = tag
      -- Mini.ai with LazyVim also includes comments via treesitter
      
      return opts
    end,
  },

  -- Additional text objects via targets.vim for next/last variants
  {
    "wellle/targets.vim",
    event = "VeryLazy",
    -- Provides:
    -- - Next/last text objects (in/an, il/al for next/last parentheses, etc.)
    -- - Seeking behavior for text objects (automatically find next occurrence)
  },

  -- Indentation text objects (i, j, k)
  {
    "michaeljsmith/vim-indent-object",
    event = "VeryLazy",
    -- Provides:
    -- ii - inner indentation level (no line above/below)
    -- ai - an indentation level (no line above/below)
    -- iI - inner indentation level (with line above)
    -- aI - an indentation level (with line above/below)
  },

  -- Additional text objects for subwords and more
  {
    "chrisgrieser/nvim-various-textobjs",
    event = "VeryLazy",
    opts = {
      keymaps = {
        useDefaults = false,
      },
    },
    config = function(_, opts)
      require("various-textobjs").setup(opts)
      
      -- Subword text objects for camelCase/snake_case segments
      vim.keymap.set({ "o", "x" }, "iS", function()
        require("various-textobjs").subword(true)
      end, { desc = "Inner subword" })
      vim.keymap.set({ "o", "x" }, "aS", function()
        require("various-textobjs").subword(false)
      end, { desc = "Around subword" })
      
      -- Value text objects (useful for key-value pairs)
      vim.keymap.set({ "o", "x" }, "iv", function()
        require("various-textobjs").value()
      end, { desc = "Inner value" })
      vim.keymap.set({ "o", "x" }, "av", function()
        require("various-textobjs").value()
      end, { desc = "Around value" })
    end,
  },

  -- XML/HTML attributes text objects (x)
  {
    "whatyouhide/vim-textobj-xmlattr",
    dependencies = "kana/vim-textobj-user",
    event = { "BufReadPost *.html", "BufReadPost *.xml", "BufReadPost *.jsx", "BufReadPost *.tsx" },
    -- Provides ix and ax for XML/HTML attributes
  },
}