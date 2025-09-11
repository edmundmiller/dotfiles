-- Fix treesitter highlighting for custom filetypes
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      highlight = {
        enable = true,
        -- Ensure these filetypes are not disabled
        additional_vim_regex_highlighting = false,
      },
      -- Ensure these parsers are installed
      ensure_installed = {
        "lua",
        "vim",
        "vimdoc",
        "groovy",
      },
    },
    config = function(_, opts)
      -- Ensure parsers for our custom languages are registered
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
      
      -- Register Nextflow parser
      parser_config.nextflow = {
        install_info = {
          url = "https://github.com/nextflow-io/tree-sitter-nextflow",
          files = { "src/parser.c" },
          branch = "rewrite",
          generate_requires_npm = false,
        },
        filetype = "nextflow",
      }
      
      -- Setup treesitter
      require("nvim-treesitter.configs").setup(opts)
      
      -- Force enable highlighting for specific filetypes
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "nextflow", "todotxt" },
        callback = function(ev)
          -- Small delay to ensure parser is loaded
          vim.defer_fn(function()
            local buf = ev.buf
            -- Try to start treesitter highlighting
            pcall(vim.treesitter.start, buf)
          end, 100)
        end,
      })
    end,
  },
}