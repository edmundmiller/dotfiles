-- nvim-dev-container - Development container support for Neovim
-- Provides VSCode-like dev container functionality

---@type LazySpec
return {
  {
    "https://codeberg.org/esensar/nvim-dev-container",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      -- Use default configuration
      -- Available options:
      -- config_search_start: function to find starting point for .devcontainer.json search
      -- workspace_folder_provider: function to replace ${localWorkspaceFolder} in devcontainer.json
      -- terminal_handler: function for custom terminal handling
      -- nvim_installation_commands_provider: function for custom nvim installation commands
    },
    keys = {
      -- Dev Container keybindings
      { "<leader>D", desc = "Dev Container" },
      { "<leader>Ds", "<cmd>DevcontainerStart<cr>", desc = "Start dev container" },
      { "<leader>Da", "<cmd>DevcontainerAttach<cr>", desc = "Attach to dev container" },
      { "<leader>Dx", "<cmd>DevcontainerExec<cr>", desc = "Execute command in container" },
      { "<leader>Dt", "<cmd>DevcontainerStop<cr>", desc = "Stop dev container" },
      { "<leader>De", "<cmd>DevcontainerEditNearestConfig<cr>", desc = "Edit devcontainer.json" },
      { "<leader>DS", "<cmd>DevcontainerStopAll<cr>", desc = "Stop all containers" },
      { "<leader>DR", "<cmd>DevcontainerRemoveAll<cr>", desc = "Remove all containers" },
    },
  },
}
