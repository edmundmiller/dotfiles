-- split.nvim: Smart sentence line breaks for academic writing
return {
  "wurli/split.nvim",
  ft = { "markdown", "tex", "text", "org" }, -- Load for text-based files
  config = function()
    local split = require("split")
    
    -- Setup split.nvim with default configuration
    split.setup({
      -- Default settings (disabled globally)
      enabled = false,
    })
    
    -- Auto-enable for dissertation directory only
    vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile" }, {
      pattern = { "*.md", "*.tex", "*.txt", "*.org" },
      callback = function()
        local file_path = vim.fn.expand("%:p")
        -- Check if we're in the dissertation directory
        if file_path:match("^" .. vim.fn.expand("~/Documents/Dissertation")) then
          -- Enable split.nvim for this buffer
          vim.b.split_enabled = true
          vim.notify("Split.nvim enabled for dissertation", vim.log.levels.INFO)
        else
          -- Disable split.nvim for other directories
          vim.b.split_enabled = false
        end
      end,
    })
  end,
  keys = {
    -- Manual controls (work in any buffer)
    { "<leader>ts", function() require("split").toggle() end, desc = "Toggle sentence splits" },
    { "gS", function() require("split").split() end, desc = "Split sentences", mode = { "n", "v" } },
    { "gJ", function() require("split").join() end, desc = "Join sentences", mode = { "n", "v" } },
  },
}