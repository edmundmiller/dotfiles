-- Onedark theme configuration with enhanced highlighting
return {
  {
    "navarasu/onedark.nvim",
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      require('onedark').setup {
        style = 'darker',
        transparent = false,  -- Set to true if you want terminal background
        term_colors = true,   -- Change terminal colors for better integration
        ending_tildes = false, -- Don't show end-of-buffer tildes
        cmp_itemkind_reverse = false,
        
        -- Code style configuration for better visual hierarchy
        code_style = {
          comments = 'italic',
          keywords = 'bold',
          functions = 'italic',
          strings = 'none',
          variables = 'none'
        },
        
        -- Lualine configuration
        lualine = {
          transparent = false,
        },
        
        -- Custom highlights for enhanced visibility
        highlights = {
          -- Better treesitter support
          ["@keyword"] = { fmt = 'bold' },
          ["@function"] = { fmt = 'italic' },
          ["@comment"] = { fmt = 'italic' },
          ["@constant.builtin"] = { fmt = 'bold' },
          ["@variable.parameter"] = { fg = '$orange' },
          
          -- Better LSP highlights
          ["@lsp.type.function"] = { fmt = 'italic' },
          ["@lsp.type.parameter"] = { fg = '$orange' },
          ["@lsp.type.keyword"] = { fmt = 'bold' },
          
          -- Enhanced diff colors
          ["DiffAdd"] = { bg = '#1e3a1e' },
          ["DiffDelete"] = { bg = '#3a1e1e' },
          ["DiffChange"] = { bg = '#1e2a3a' },
        },
        
        -- Diagnostic colors for better visibility
        diagnostics = {
          darker = true,     -- Darker colors for diagnostics
          undercurl = true,  -- Use undercurl for diagnostics
          background = true, -- Add background to virtual text
        },
      }
      -- Enable theme
      require('onedark').load()
    end
  }
}