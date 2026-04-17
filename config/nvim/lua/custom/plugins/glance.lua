-- https://github.com/DNLHC/glance.nvim
-- VS Code-style LSP peek UI for definitions, references, implementations, and types

return {
  {
    'dnlhc/glance.nvim',
    cmd = 'Glance',
    keys = {
      { 'gD', '<CMD>Glance definitions<CR>', desc = 'Glance: definitions' },
      { 'gR', '<CMD>Glance references<CR>', desc = 'Glance: references' },
      { 'gY', '<CMD>Glance type_definitions<CR>', desc = 'Glance: type definitions' },
      { 'gM', '<CMD>Glance implementations<CR>', desc = 'Glance: implementations' },
    },
    opts = {
      preserve_win_context = true,
      detached = function(winid)
        return vim.api.nvim_win_get_width(winid) < 100
      end,
      preview_win_opts = {
        cursorline = true,
        number = true,
        wrap = true,
      },
      border = {
        enable = false,
      },
      list = {
        position = 'right',
        width = 0.33,
      },
      theme = {
        enable = true,
        mode = 'auto',
      },
    },
  },
}
