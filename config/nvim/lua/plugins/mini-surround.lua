return {
  {
    "echasnovski/mini.surround",
    opts = {
      mappings = {
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
    },
    keys = {
      { "S", [[:<C-u>lua MiniSurround.add('visual')<CR>]], mode = "x", silent = true, desc = "Add surrounding" },
    },
  },
}