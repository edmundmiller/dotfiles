return {
  'folke/zen-mode.nvim',
  cmd = 'ZenMode',
  keys = {
    { '<leader>tz', '<cmd>ZenMode<cr>', desc = 'Toggle [Z]en mode' },
  },
  opts = {
    window = {
      width = 90,
    },
  },
}
