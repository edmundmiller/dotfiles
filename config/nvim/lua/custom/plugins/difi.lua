-- difi.nvim - Neovim companion for the difi structured git diff reviewer
-- Provides visual inline diffs and jump-to-line from the difi CLI
return {
  {
    'oug-t/difi.nvim',
    event = 'VeryLazy',
    keys = {
      { '<leader>df', ':Difi<CR>', desc = 'Difi: toggle diff (HEAD)' },
    },
  },
}
