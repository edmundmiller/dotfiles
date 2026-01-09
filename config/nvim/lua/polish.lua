-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- Trigger tmux-window-name update when entering/leaving Neovim
local uv = vim.uv or vim.loop

vim.api.nvim_create_autocmd({ 'VimEnter', 'VimLeave' }, {
  callback = function()
    if vim.env.TMUX_WINDOW_NAME_SCRIPT then
      uv.spawn(vim.env.TMUX_WINDOW_NAME_SCRIPT, {})
    end
  end,
})
