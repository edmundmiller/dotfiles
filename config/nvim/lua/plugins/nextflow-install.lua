-- Nextflow parser manual installation helper (DEPRECATED - use lang-nextflow.lua instead)
-- This file is kept for reference but should not be used
-- stylua: ignore
if true then return {} end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    config = function()
      -- Create a command to install Nextflow parser
      vim.api.nvim_create_user_command("InstallNextflowParser", function()
        -- Register filetype for nextflow
        vim.filetype.add({
          extension = {
            nf = "nextflow",
          },
          pattern = {
            [".*%.nextflow"] = "nextflow",
          },
        })

        -- Register language for treesitter
        vim.treesitter.language.register("nextflow", "nextflow")

        -- Now install the parser
        vim.cmd("TSInstall nextflow")
      end, {
        desc = "Install Nextflow treesitter parser",
      })
    end,
  },
}