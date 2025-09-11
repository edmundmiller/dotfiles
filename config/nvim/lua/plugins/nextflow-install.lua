-- Nextflow parser manual installation helper
return {
  {
    "nvim-treesitter/nvim-treesitter",
    config = function()
      -- Create a command to install Nextflow parser
      vim.api.nvim_create_user_command("InstallNextflowParser", function()
        -- First, ensure the parser config is registered
        local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
        parser_config.nextflow = {
          install_info = {
            url = "https://github.com/nextflow-io/tree-sitter-nextflow",
            files = { "src/parser.c" },
            branch = "rewrite",
            generate_requires_npm = false,
          },
          filetype = "nextflow",
        }
        
        -- Now install the parser
        vim.cmd("TSInstall nextflow")
      end, {
        desc = "Install Nextflow treesitter parser from rewrite branch",
      })
      
      -- Also register the parser config on startup
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
      parser_config.nextflow = {
        install_info = {
          url = "https://github.com/nextflow-io/tree-sitter-nextflow",
          files = { "src/parser.c" },
          branch = "rewrite",
          generate_requires_npm = false,
        },
        filetype = "nextflow",
      }
    end,
  },
}