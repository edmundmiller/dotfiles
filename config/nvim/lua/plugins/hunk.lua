-- Hunk.nvim - Interactive diff editor for git hunks (perfect for jujutsu)
-- To use with jujutsu, add to your jj config:
-- [ui]
-- diff-editor = ["nvim", "-c", "DiffEditor $left $right $output"]
return {
  {
    "julienvincent/hunk.nvim",
    cmd = { "DiffEditor" },
    dependencies = {
      "MunifTanjim/nui.nvim",
      -- Optional: for file icons (one of these)
      { "nvim-tree/nvim-web-devicons", optional = true },
      { "nvim-mini/mini.icons", optional = true },
    },
    config = function()
      require("hunk").setup({
        keys = {
          global = {
            quit = { "q" },
            accept = { "<leader><CR>" },
            focus_tree = { "<leader>e" },
          },
          tree = {
            expand_node = { "l", "<Right>" },
            collapse_node = { "h", "<Left>" },
            open_file = { "<CR>" },
            toggle_file = { "a" },
          },
          diff = {
            toggle_hunk = { "A" },
            toggle_line = { "a" },
            -- Toggle line on both sides of the diff
            toggle_line_pair = { "s" },
            prev_hunk = { "[h" },
            next_hunk = { "]h" },
            -- Jump between left and right diff view
            toggle_focus = { "<Tab>" },
          },
        },
        ui = {
          tree = {
            mode = "nested", -- or "flat"
            width = 35,
          },
          layout = "vertical", -- or "horizontal"
        },
        icons = {
          selected = "󰡖",
          deselected = "",
          partially_selected = "󰛲",
          folder_open = "",
          folder_closed = "",
        },
        hooks = {
          -- Disable spell checking in the file tree
          on_tree_mount = function(context)
            vim.api.nvim_set_option_value("spell", false, { win = context.win })
          end,
        },
      })
    end,
  },
}