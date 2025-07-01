-- Override conflicting keymaps from LazyVim extras
return {
  -- Override yanky keymaps to avoid conflict with Doom's <leader>p (project)
  {
    "gbprod/yanky.nvim",
    keys = {
      -- Disable the default <leader>p keymap
      { "<leader>p", false },
      -- Remap yanky to <leader>y (yank) instead of <leader>p (project)
      {
        "<leader>yp",
        function()
          require("telescope").extensions.yank_history.yank_history({})
        end,
        desc = "Open Yank History",
      },
    },
  },

  -- Override harpoon keymaps to avoid conflict with Doom's <leader>h (help)
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    keys = {
      -- Disable the default <leader>h keymap
      { "<leader>h", false },
      -- Remap harpoon to <leader>j (jump) instead of <leader>h (help)
      {
        "<leader>ja",
        function()
          require("harpoon"):list():add()
        end,
        desc = "Harpoon File",
      },
      {
        "<leader>jh",
        function()
          local harpoon = require("harpoon")
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end,
        desc = "Harpoon Quick Menu",
      },
      {
        "<leader>j1",
        function()
          require("harpoon"):list():select(1)
        end,
        desc = "Harpoon to File 1",
      },
      {
        "<leader>j2",
        function()
          require("harpoon"):list():select(2)
        end,
        desc = "Harpoon to File 2",
      },
      {
        "<leader>j3",
        function()
          require("harpoon"):list():select(3)
        end,
        desc = "Harpoon to File 3",
      },
      {
        "<leader>j4",
        function()
          require("harpoon"):list():select(4)
        end,
        desc = "Harpoon to File 4",
      },
      {
        "<leader>j5",
        function()
          require("harpoon"):list():select(5)
        end,
        desc = "Harpoon to File 5",
      },
      {
        "<leader>jp",
        function()
          require("harpoon"):list():prev()
        end,
        desc = "Harpoon Prev",
      },
      {
        "<leader>jn",
        function()
          require("harpoon"):list():next()
        end,
        desc = "Harpoon Next",
      },
    },
  },
}